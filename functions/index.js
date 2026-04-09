const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendFCMNotification = functions.firestore
  .document("fcm_queue/{docId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data.token || data.sent === true) return null;

    // Try to get logo URL from settings, fallback to empty
    let logoUrl = "";
    try {
      const settingsDoc = await admin.firestore().collection("app_settings").doc("logo").get();
      if (settingsDoc.exists) {
        logoUrl = settingsDoc.data().url || "";
      }
    } catch (_) {}

    const notification = {
      title: data.title || "داوملي",
      body: data.body || "",
    };
    if (logoUrl) notification.imageUrl = logoUrl;

    const androidNotification = {
      channelId: "dawemly_channel",
      icon: "ic_notification",
      color: "#175CD3",
    };
    if (logoUrl) androidNotification.imageUrl = logoUrl;

    const message = {
      token: data.token,
      notification: notification,
      android: {
        priority: "high",
        notification: androidNotification,
      },
      apns: {
        payload: {
          aps: {
            alert: { title: data.title || "داوملي", body: data.body || "" },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      await snap.ref.update({ sent: true, sentAt: admin.firestore.FieldValue.serverTimestamp() });
      console.log("FCM sent successfully");
    } catch (error) {
      console.error("FCM error:", error);
      await snap.ref.update({ sent: false, error: error.message });
    }

    return null;
  });
