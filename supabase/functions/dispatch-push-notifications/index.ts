import { createClient } from "jsr:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9.15.1";

type PushJobRow = {
  id: string;
  attempt_count: number;
  notification_id: string;
  notifications: NotificationRow | NotificationRow[] | null;
};

type NotificationRow = {
  id: string;
  studio_id: string;
  user_id: string;
  kind: string;
  title: string;
  body: string;
  is_important: boolean;
  related_entity_type: string | null;
  related_entity_id: string | null;
};

type DeviceRow = {
  id: string;
  token: string;
  platform: "android" | "ios";
};

const jsonHeaders = { "Content-Type": "application/json" };
const pushScope = "https://www.googleapis.com/auth/firebase.messaging";
const androidNotificationChannelId = "eightup_notifications";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const firebaseProjectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "";

if (!supabaseUrl || !serviceRoleKey) {
  throw new Error("SUPABASE_URL 또는 SUPABASE_SERVICE_ROLE_KEY가 설정되지 않았습니다.");
}

if (!firebaseProjectId || !serviceAccountJson) {
  throw new Error("FCM_PROJECT_ID 또는 FIREBASE_SERVICE_ACCOUNT_JSON이 설정되지 않았습니다.");
}

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const googleAuth = new GoogleAuth({
  credentials: JSON.parse(serviceAccountJson),
  scopes: [pushScope],
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: jsonHeaders },
    );
  }

  try {
    const body = await request.json().catch(() => ({}));
    const batchSize = clampBatchSize(body?.batch_size);
    const processed = await dispatchPendingPushNotifications(batchSize);
    return new Response(
      JSON.stringify(processed),
      { status: 200, headers: jsonHeaders },
    );
  } catch (error) {
    console.error("dispatch-push-notifications failed", formatError(error));
    return new Response(
      JSON.stringify({ error: formatError(error) }),
      { status: 500, headers: jsonHeaders },
    );
  }
});

async function dispatchPendingPushNotifications(batchSize: number) {
  const { data: jobs, error } = await supabase
    .from("notification_push_jobs")
    .select(
      `
        id,
        attempt_count,
        notification_id,
        notifications (
          id,
          studio_id,
          user_id,
          kind,
          title,
          body,
          is_important,
          related_entity_type,
          related_entity_id
        )
      `,
    )
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(batchSize);

  if (error != null) {
    throw error;
  }

  if ((jobs ?? []).length === 0) {
    return {
      claimedCount: 0,
      deliveredCount: 0,
      skippedCount: 0,
      failedCount: 0,
    };
  }

  const accessToken = await googleAuth.getAccessToken();
  if (!accessToken) {
    throw new Error("FCM access token을 가져오지 못했습니다.");
  }

  let claimedCount = 0;
  let deliveredCount = 0;
  let skippedCount = 0;
  let failedCount = 0;

  for (const rawJob of (jobs ?? []) as PushJobRow[]) {
    const notification = normalizeNotification(rawJob.notifications);
    if (notification == null) {
      await finishJob(rawJob.id, {
        status: "skipped",
        processed_at: new Date().toISOString(),
        last_error: "알림 원본을 찾을 수 없습니다.",
      });
      skippedCount += 1;
      continue;
    }

    const claimed = await claimJob(rawJob.id, rawJob.attempt_count);
    if (!claimed) {
      continue;
    }
    claimedCount += 1;

    if (!shouldSendAsPush(notification)) {
      await finishJob(rawJob.id, {
        status: "skipped",
        processed_at: new Date().toISOString(),
        last_error: "푸쉬 허용 대상이 아닌 알림입니다.",
      });
      skippedCount += 1;
      continue;
    }

    const result = await sendNotificationToDevices(notification, rawJob.id, accessToken);

    if (result.retryableFailure) {
      const shouldRetry = rawJob.attempt_count + 1 < 3;
      await finishJob(rawJob.id, {
        status: shouldRetry ? "pending" : "failed",
        last_error: result.retryableFailure,
        processed_at: shouldRetry ? null : new Date().toISOString(),
      });
      failedCount += 1;
      continue;
    }

    if (result.sentCount > 0) {
      await finishJob(rawJob.id, {
        status: "sent",
        processed_at: new Date().toISOString(),
        last_error: null,
      });
      deliveredCount += result.sentCount;
      continue;
    }

    await finishJob(rawJob.id, {
      status: "skipped",
      processed_at: new Date().toISOString(),
      last_error: result.skipReason ?? "활성화된 푸쉬 기기가 없습니다.",
    });
    skippedCount += 1;
  }

  return {
    claimedCount,
    deliveredCount,
    skippedCount,
    failedCount,
  };
}

async function claimJob(jobId: string, attemptCount: number) {
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from("notification_push_jobs")
    .update({
      status: "processing",
      attempt_count: attemptCount + 1,
      last_attempt_at: now,
      updated_at: now,
    })
    .eq("id", jobId)
    .eq("status", "pending")
    .select("id")
    .maybeSingle();

  if (error != null) {
    throw error;
  }

  return data != null;
}

async function finishJob(
  jobId: string,
  patch: {
    status: "pending" | "sent" | "skipped" | "failed";
    processed_at?: string | null;
    last_error?: string | null;
  },
) {
  const payload = {
    status: patch.status,
    processed_at: patch.processed_at ?? null,
    last_error: patch.last_error ?? null,
    updated_at: new Date().toISOString(),
  };

  const { error } = await supabase
    .from("notification_push_jobs")
    .update(payload)
    .eq("id", jobId);

  if (error != null) {
    throw error;
  }
}

async function sendNotificationToDevices(
  notification: NotificationRow,
  jobId: string,
  accessToken: string,
) {
  const { data: devices, error } = await supabase
    .from("push_notification_devices")
    .select("id, token, platform")
    .eq("user_id", notification.user_id)
    .eq("push_enabled", true);

  if (error != null) {
    throw error;
  }

  const activeDevices = (devices ?? []) as DeviceRow[];
  if (activeDevices.length === 0) {
    return { sentCount: 0, skipReason: "활성화된 푸쉬 기기가 없습니다." };
  }

  const { data: existingDeliveries, error: deliveryError } = await supabase
    .from("notification_push_deliveries")
    .select("device_id")
    .eq("notification_id", notification.id);

  if (deliveryError != null) {
    throw deliveryError;
  }

  const deliveredDeviceIds = new Set(
    (existingDeliveries ?? []).map((row: { device_id: string }) => row.device_id),
  );

  let sentCount = 0;
  let retryableFailure: string | null = null;
  let skippedCount = 0;

  for (const device of activeDevices) {
    if (deliveredDeviceIds.has(device.id)) {
      skippedCount += 1;
      continue;
    }

    const response = await sendFcmMessage(notification, device, accessToken);
    const responseText = await response.text();
    const responseBody = safeJson(responseText);
    const invalidToken = isInvalidTokenResponse(response.status, responseBody, responseText);

    await upsertDelivery({
      jobId,
      notificationId: notification.id,
      device,
      deliveryStatus: response.ok
          ? "sent"
          : invalidToken
          ? "invalid"
          : "failed",
      responseCode: response.status,
      responseBody,
      errorMessage: response.ok ? null : responseText,
    });

    if (response.ok) {
      sentCount += 1;
      continue;
    }

    if (invalidToken) {
      await disableDevice(device.id);
      continue;
    }

    if (retryableFailure == null) {
      retryableFailure = responseText.length === 0
          ? `FCM 전송 실패 (${response.status})`
          : responseText;
    }
  }

  return {
    sentCount,
    skippedCount,
    skipReason: sentCount == 0 && skippedCount > 0
        ? "이미 처리된 기기만 남아 있습니다."
        : null,
    retryableFailure,
  };
}

async function sendFcmMessage(
  notification: NotificationRow,
  device: DeviceRow,
  accessToken: string,
) {
  const baseData = {
    notification_id: notification.id,
    studio_id: notification.studio_id,
    kind: notification.kind,
    is_important: notification.is_important ? "true" : "false",
    related_entity_type: notification.related_entity_type ?? "",
    related_entity_id: notification.related_entity_id ?? "",
    title: notification.title,
    body: notification.body,
  };

  const payload = device.platform === "android"
    ? {
      message: {
        token: device.token,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: baseData,
        android: {
          priority: "high",
          notification: {
            channel_id: androidNotificationChannelId,
            sound: "default",
          },
        },
      },
    }
    : {
      message: {
        token: device.token,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: baseData,
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: {
                title: notification.title,
                body: notification.body,
              },
              sound: "default",
            },
          },
        },
      },
    };

  return await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`,
      },
      body: JSON.stringify(payload),
    },
  );
}

async function upsertDelivery(args: {
  jobId: string;
  notificationId: string;
  device: DeviceRow;
  deliveryStatus: "sent" | "failed" | "invalid" | "skipped";
  responseCode: number;
  responseBody: unknown;
  errorMessage: string | null;
}) {
  const { error } = await supabase
    .from("notification_push_deliveries")
    .upsert(
      {
        job_id: args.jobId,
        notification_id: args.notificationId,
        device_id: args.device.id,
        token_snapshot: args.device.token,
        delivery_status: args.deliveryStatus,
        response_code: args.responseCode,
        response_body: args.responseBody,
        error_message: args.errorMessage,
      },
      { onConflict: "notification_id,device_id" },
    );

  if (error != null) {
    throw error;
  }
}

async function disableDevice(deviceId: string) {
  const { error } = await supabase
    .from("push_notification_devices")
    .update({
      push_enabled: false,
      disabled_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", deviceId);

  if (error != null) {
    throw error;
  }
}

function clampBatchSize(rawValue: unknown) {
  const parsed = Number(rawValue);
  if (!Number.isFinite(parsed)) {
    return 50;
  }
  return Math.min(Math.max(Math.trunc(parsed), 1), 200);
}

function normalizeNotification(
  notification: NotificationRow | NotificationRow[] | null,
) {
  if (notification == null) {
    return null;
  }

  if (Array.isArray(notification)) {
    return notification[0] ?? null;
  }

  return notification;
}

function safeJson(rawText: string) {
  if (!rawText) {
    return null;
  }

  try {
    return JSON.parse(rawText);
  } catch (_) {
    return { raw: rawText };
  }
}

function shouldSendAsPush(notification: NotificationRow) {
  const pushKinds = new Set([
    "session_cancelled",
    "session_instructor_changed",
    "session_reservation_removed",
    "waitlist_promoted",
    "cancel_request_approved",
    "cancel_request_rejected",
    "session_reminder_day_before",
    "session_reminder_hour_before",
  ]);

  if (pushKinds.has(notification.kind)) {
    return true;
  }

  if (
    (notification.kind === "notice" || notification.kind === "event") &&
    notification.is_important
  ) {
    return true;
  }

  return false;
}

function isInvalidTokenResponse(
  status: number,
  responseBody: unknown,
  rawText: string,
) {
  if (status !== 400 && status !== 404) {
    return false;
  }

  const serialized = typeof responseBody === "string"
    ? responseBody
    : JSON.stringify(responseBody ?? rawText);
  return serialized.includes("UNREGISTERED") ||
    serialized.includes("registration-token-not-registered") ||
    serialized.includes("invalid registration token") ||
    serialized.includes("INVALID_ARGUMENT");
}

function formatError(error: unknown) {
  if (error instanceof Error) {
    return error.stack ?? error.message;
  }

  if (typeof error === "string") {
    return error;
  }

  if (error && typeof error === "object") {
    const candidate = error as Record<string, unknown>;
    const normalized = {
      message: candidate.message,
      code: candidate.code,
      details: candidate.details,
      hint: candidate.hint,
      status: candidate.status,
      statusCode: candidate.statusCode,
      cause: candidate.cause,
      error: candidate.error,
    };

    try {
      return JSON.stringify(normalized);
    } catch (_) {
      return String(error);
    }
  }

  return String(error);
}
