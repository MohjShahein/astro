import 'package:cloud_firestore/cloud_firestore.dart';

class GiftService {
  static Future<void> addGift(String giftId, String name, double price) async {
    await FirebaseFirestore.instance.collection('gifts').doc(giftId).set({
      'name': name,
      'price': price,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> getGifts() {
    return FirebaseFirestore.instance.collection('gifts').snapshots();
  }
}