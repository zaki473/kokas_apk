const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.kirimNotifPengumuman = functions.firestore
    .document("announcements/{announcementId}") // Memantau koleksi announcements
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const groupId = data.groupId;
        const pesan = data.pesan;
        const pembuat = data.author;

        // Payload Notifikasi
        const message = {
            notification: {
                title: `📢 Pengumuman: ${pembuat}`,
                body: pesan,
            },
            android: {
                notification: {
                    channelId: "high_importance_channel", // Agar muncul melayang
                    priority: "high",
                },
            },
            topic: `group_${groupId}`, // Kirim ke topik grup
        };

        try {
            await admin.messaging().send(message);
            console.log(`Notif berhasil dikirim ke grup: ${groupId}`);
        } catch (error) {
            console.log("Gagal kirim notif:", error);
        }
    });