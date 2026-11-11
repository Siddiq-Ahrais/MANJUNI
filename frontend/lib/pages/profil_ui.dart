import 'package:flutter/material.dart';

class ProfilUI extends StatelessWidget {
  const ProfilUI({super.key});

  final Color kGreen = const Color(0xFF1E874B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildStats(),
            const SizedBox(height: 16),
            _buildSyncSettings(),
            const SizedBox(height: 16),
            _buildMenuItems(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
            const SizedBox(height: 16),
            const Text('Versi 1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFA5D6A7), // Light green
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20), // Dark green
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('MJ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Warung Maju Jaya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                SizedBox(height: 4),
                Text('Warung Sembako • UMKM', style: TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.edit, size: 20, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC80), // Light orange
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Produk Terdaftar', style: TextStyle(fontSize: 12, color: Colors.black87)),
                SizedBox(height: 8),
                Text('48', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFBBDEFB), // Light blue
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pelanggan Kasbon', style: TextStyle(fontSize: 12, color: Colors.black87)),
                SizedBox(height: 8),
                Text('2 Orang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.black87)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.access_time, color: Colors.green),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mode Offline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Data disimpan di perangkat', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Switch(
                value: true,
                onChanged: (val) {},
                activeColor: Colors.white,
                activeTrackColor: kGreen,
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sinkronisasi terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('Rabu, 15 Okt 2024 • 13:50 • 2 data menunggu', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: kGreen,
                  side: BorderSide(color: kGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Sinkron'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _buildMenuItem(Icons.storefront, 'Info Toko', Colors.green.shade50, Colors.green),
          const Divider(height: 1, indent: 64),
          _buildMenuItem(Icons.people_outline, 'Pelanggan & Kasbon', Colors.blue.shade50, Colors.blue),
          const Divider(height: 1, indent: 64),
          _buildMenuItem(Icons.print_outlined, 'Printer & Struk', Colors.orange.shade50, Colors.orange),
          const Divider(height: 1, indent: 64),
          _buildMenuItem(Icons.cloud_upload_outlined, 'Cadangkan Data', Colors.green.shade50, Colors.green),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color bgColor, Color iconColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Warung Maju Jaya',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Icon(Icons.menu, size: 20),
        ),
      ],
    );
  }
}