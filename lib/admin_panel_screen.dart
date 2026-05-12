import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'animations.dart';
import 'firestore_service.dart';
import 'masjid_model.dart';
import 'user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'log_model.dart';
import 'change_request_model.dart';
import 'verify_changes_screen.dart';
import 'feedback_model.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final FirestoreService _db = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)),
            onPressed: () => Navigator.pop(context),
          ),
          title: _buildSearchBar(),
          actions: [
            // --- DELETE ALL BUTTON ---
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: "Delete ALL Masjids",
              onPressed: () async {
                bool confirm = await showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: AppColors.creamCard(context),
                      title: const Text("Danger Zone!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      content: Text("Are you sure you want to DELETE ALL MASJIDS? This cannot be undone.", style: TextStyle(color: AppColors.textDark(context))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                        TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text("DELETE EVERYTHING", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                        ),
                      ],
                    )
                ) ?? false;

                if (confirm) {
                  await _db.deleteAllMasjids();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All Masjids Deleted.")));
                  }
                }
              },
            )
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primaryMint(context),
            labelColor: AppColors.textDark(context),
            unselectedLabelColor: AppColors.accentBeige(context),
            tabs: const [
              Tab(text: "Dashboard"),
              Tab(text: "Requests"),
              Tab(text: "Masjids"),
              Tab(text: "Users"),
              Tab(text: "Logs"),
              Tab(text: "Duas"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDashboard(),
            _buildRequestsList(),
            _buildMasjidsList(),
            _buildUsersList(),
            _buildLogsList(),
            _buildFeedbackList(),
          ],
        ),
      ),
    );
  }


  Widget _buildFeedbackList() {
    return StreamBuilder<List<FeedbackModel>>(
      stream: _db.getAllFeedback(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return Center(child: Text("No feedback yet.", style: TextStyle(color: AppColors.textDark(context))));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return Card(
              color: AppColors.creamCard(context),
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(item.message, style: TextStyle(color: AppColors.textDark(context))),
                subtitle: Text("- ${item.userName} (${item.rating}★)\n${DateFormat('MMM d, h:mm a').format(item.timestamp)}", style: TextStyle(color: AppColors.accentBeige(context), fontSize: 12)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.creamCard(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        style: TextStyle(color: AppColors.textDark(context)),
        decoration: InputDecoration(
          hintText: "Search...",
          hintStyle: TextStyle(color: AppColors.accentBeige(context)),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, size: 20, color: AppColors.accentBeige(context)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // --- DASHBOARD ---
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          StreamBuilder<List<UserModel>>(
            stream: _db.getUsers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final users = snapshot.data!;

              final now = DateTime.now();
              final todayUsers = users.where((u) => u.createdAt.day == now.day && u.createdAt.month == now.month && u.createdAt.year == now.year).toList();
              final weekUsers = users.where((u) => now.difference(u.createdAt).inDays < 7).toList();
              final monthUsers = users.where((u) => u.createdAt.month == now.month && u.createdAt.year == now.year).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("User Analytics", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard("Total Users", "${users.length}", Icons.group, Colors.blue, onTap: () => _showFilteredList(context, "All Users", users))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard("Joined Today", "+${todayUsers.length}", Icons.today, Colors.orange, onTap: () => _showFilteredList(context, "Joined Today", todayUsers))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard("This Week", "+${weekUsers.length}", Icons.date_range, Colors.purple, onTap: () => _showFilteredList(context, "Joined This Week", weekUsers))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard("This Month", "+${monthUsers.length}", Icons.calendar_month, Colors.teal, onTap: () => _showFilteredList(context, "Joined This Month", monthUsers))),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          StreamBuilder<List<Masjid>>(
            stream: _db.getMasjids(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final masjids = snapshot.data!;

              final verified = masjids.where((m) => m.isVerified).toList();
              final pending = masjids.where((m) => !m.isVerified).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Masjid Analytics", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _statCard("Total Masjids", "${masjids.length}", Icons.mosque, Colors.indigo, onTap: () => _showFilteredList(context, "All Masjids", masjids))),
                      const SizedBox(width: 12),
                      Expanded(child: _statCard("Verified", "${verified.length}", Icons.verified, Colors.green, onTap: () => _showFilteredList(context, "Verified Masjids", verified))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _statCard("Pending Approval", "${pending.length}", Icons.pending_actions, Colors.redAccent, onTap: () => _showFilteredList(context, "Pending Approval", pending)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String count, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.creamCard(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 28),
                Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.accentBeige(context)),
              ],
            ),
            const SizedBox(height: 12),
            Text(count, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark(context))),
            Text(title, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDark(context).withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  void _showFilteredList(BuildContext context, String title, List<dynamic> items) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FilteredListScreen(title: title, items: items))
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<List<ChangeRequestModel>>(
      stream: _db.getAllChangeRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var reqs = snapshot.data!;
        if (reqs.isEmpty) return Center(child: Text("No Pending Requests", style: TextStyle(color: AppColors.textDark(context))));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: reqs.length,
          itemBuilder: (context, index) {
            final req = reqs[index];
            return Card(
              color: AppColors.creamCard(context),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.edit_note, color: Colors.orange, size: 30),
                title: Text(req.masjidName, style: TextStyle(color: AppColors.textDark(context), fontWeight: FontWeight.bold)),
                subtitle: Text("By: ${req.userName}\n${DateFormat('MMM d, h:mm a').format(req.timestamp)}", style: TextStyle(color: AppColors.accentBeige(context), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyChangesScreen(masjidId: req.masjidId)));
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMasjidsList() {
    return StreamBuilder<List<Masjid>>(
      stream: _db.getMasjids(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var masjids = snapshot.data!;
        if (_searchQuery.isNotEmpty) {
          masjids = masjids.where((m) =>
          m.name.toLowerCase().contains(_searchQuery) ||
              m.address.toLowerCase().contains(_searchQuery)
          ).toList();
        }

        if (masjids.isEmpty) return Center(child: Text("No Masjids found", style: TextStyle(color: AppColors.textDark(context))));

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: masjids.length,
          itemBuilder: (context, index) {
            final m = masjids[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.creamCard(context), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: Text(m.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppColors.textDark(context)))),
                    if (m.isVerified) const Icon(Icons.verified, color: Colors.blue, size: 18),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (!m.isVerified)
                      TextButton(onPressed: () => _db.verifyMasjid(m.id), child: const Text("Verify", style: TextStyle(color: Colors.blue))),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, _db, m.id)),
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<List<UserModel>>(
      stream: _db.getUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var users = snapshot.data!;
        if (_searchQuery.isNotEmpty) {
          users = users.where((u) =>
          u.name.toLowerCase().contains(_searchQuery) ||
              u.email.toLowerCase().contains(_searchQuery) ||
              u.phone.contains(_searchQuery)
          ).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            return ListTile(
              title: Text(u.name, style: TextStyle(color: AppColors.textDark(context), fontWeight: FontWeight.bold)),
              subtitle: Text("${u.email}\n${u.phone.isNotEmpty ? u.phone : 'No Phone'}", style: TextStyle(color: AppColors.accentBeige(context))),
              leading: CircleAvatar(backgroundColor: AppColors.creamCard(context), child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : "?")),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }

  Widget _buildLogsList() {
    return StreamBuilder<List<LogModel>>(
      stream: _db.getLogs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var logs = snapshot.data!;
        if (_searchQuery.isNotEmpty) {
          logs = logs.where((l) =>
          l.userName.toLowerCase().contains(_searchQuery) ||
              l.masjidName.toLowerCase().contains(_searchQuery) ||
              l.action.toLowerCase().contains(_searchQuery)
          ).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              title: Text("${log.action} - ${log.masjidName}", style: TextStyle(color: AppColors.textDark(context), fontSize: 13)),
              subtitle: Text("By: ${log.userName}\n${DateFormat('MMM d, h:mm a').format(log.timestamp)}", style: TextStyle(color: AppColors.accentBeige(context), fontSize: 11)),
              leading: const Icon(Icons.history, size: 20, color: Colors.grey),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, FirestoreService db, String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          TextButton(onPressed: () { db.deleteMasjid(id); Navigator.pop(c); }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class FilteredListScreen extends StatelessWidget {
  final String title;
  final List<dynamic> items;
  final FirestoreService _db = FirestoreService();

  FilteredListScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(color: AppColors.textDark(context), fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: AppColors.textDark(context)), onPressed: () => Navigator.pop(context)),
      ),
      body: items.isEmpty
          ? Center(child: Text("No items found", style: TextStyle(color: AppColors.accentBeige(context))))
          : ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];

          if (item is UserModel) {
            return Card(
              color: AppColors.creamCard(context),
              child: ListTile(
                leading: CircleAvatar(child: Text(item.name.isNotEmpty ? item.name[0] : "?")),
                title: Text(item.name, style: TextStyle(color: AppColors.textDark(context), fontWeight: FontWeight.bold)),
                subtitle: Text("Joined: ${DateFormat('MMM d, yyyy').format(item.createdAt)}\n${item.email}", style: TextStyle(color: AppColors.accentBeige(context), fontSize: 12)),
              ),
            );
          }
          else if (item is Masjid) {
            return Card(
              color: AppColors.creamCard(context),
              child: ListTile(
                leading: const Icon(Icons.mosque, color: Colors.green),
                title: Text(item.name, style: TextStyle(color: AppColors.textDark(context), fontWeight: FontWeight.bold)),
                subtitle: Text(item.address, style: TextStyle(color: AppColors.accentBeige(context))),
                trailing: item.isVerified
                    ? const Icon(Icons.verified, color: Colors.blue)
                    : IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.orange, size: 28),
                  tooltip: "Verify this Masjid",
                  onPressed: () async {
                    await _db.verifyMasjid(item.id);
                    if(context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Masjid Verified!")));
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}