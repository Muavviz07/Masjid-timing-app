import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_colors.dart';
import 'change_request_model.dart';
import 'firestore_service.dart';
import 'main.dart';

class VerifyChangesScreen extends StatelessWidget {
  final String masjidId;
  const VerifyChangesScreen({super.key, required this.masjidId});

  @override
  Widget build(BuildContext context) {
    final FirestoreService db = FirestoreService();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)), onPressed: () => Navigator.pop(context)),
        title: Text("Verify Updates", style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<ChangeRequestModel>>(
        stream: db.getChangesForMasjid(masjidId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.isEmpty) return Center(child: Text("No pending changes.", style: TextStyle(color: AppColors.textDark(context))));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final req = snapshot.data![index];
              return _buildChangeCard(context, req, db);
            },
          );
        },
      ),
    );
  }

  Widget _buildChangeCard(BuildContext context, ChangeRequestModel req, FirestoreService db) {
    final currentUser = FirebaseAuth.instance.currentUser;
    // CHECK: IS THIS MY OWN REQUEST?
    final bool isMyRequest = currentUser != null && req.userId == currentUser.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text("Proposed by ${req.userName}${isMyRequest ? ' (You)' : ''}", style: TextStyle(color: AppColors.textDark(context), fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(),
          ...req.newData.entries.map((entry) {
            String key = entry.key;
            dynamic oldVal = req.oldData[key] ?? "N/A";
            dynamic newVal = entry.value;

            if (key == "timings") {
              return Column(
                children: (newVal as Map).entries.map((t) {
                  String prayer = t.key;
                  String oldT = (oldVal as Map)[prayer] ?? "--:--";
                  String newT = t.value;
                  if (oldT == newT) return const SizedBox.shrink();
                  return _buildDiffRow(context, "$prayer Time", oldT, newT);
                }).toList(),
              );
            }
            return _buildDiffRow(context, key.toUpperCase(), oldVal.toString(), newVal.toString());
          }),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // REJECT (Visible to everyone to flag bad info, but you can restrict if you want)
              TextButton(
                onPressed: () => db.rejectChangeRequest(req, userNameNotifier.value),
                child: const Text("Reject / Report", style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(width: 8),

              // VERIFY (Hidden/Disabled if it's your own request)
              if (isMyRequest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_empty, size: 14, color: AppColors.textDark(context).withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text("Waiting for others", style: TextStyle(color: AppColors.textDark(context).withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await db.acceptChangeRequest(req, userNameNotifier.value);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verified Successfully! +2 Points")));
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMint(context)),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text("Verify & Apply", style: TextStyle(color: Colors.white)),
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDiffRow(BuildContext context, String label, String oldVal, String newVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(color: AppColors.accentBeige(context), fontSize: 12))),
          Expanded(flex: 3, child: Text(oldVal, style: TextStyle(color: AppColors.textDark(context).withOpacity(0.5), decoration: TextDecoration.lineThrough))),
          const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
          Expanded(flex: 3, child: Text(newVal, style: TextStyle(color: AppColors.primaryMint(context), fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}