import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:committee_app/core/theme/app_colors.dart';
// import 'package:committee_app/core/theme/app_decorations.dart';

/// Reusable app drawer widget
///
/// Example usage:
/// ```dart
/// AppDrawer(
///   displayName: 'John Doe',
///   email: 'john@example.com',
///   onProfile: () => navigateToProfile(),
///   onSettings: () => navigateToSettings(),
///   onLogout: () => logout(),
///   additionalItems: [
///     DrawerMenuItem(icon: Icons.help, label: 'Help', onTap: () {}),
///   ],
/// )
/// ```
class AppDrawer extends StatelessWidget {
  final String displayName;
  final String email;
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onAbout;
  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;
  final VoidCallback? onContact;
  final VoidCallback? onLogout;
  final List<DrawerMenuItem>? additionalItems;

  const AppDrawer({
    super.key,
    required this.displayName,
    required this.email,
    this.onProfile,
    this.onSettings,
    this.onAbout,
    this.onTerms,
    this.onPrivacy,
    this.onContact,
    this.onLogout,
    this.additionalItems,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.darkSurface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(gradient: AppColors.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),

          // Profile
          if (onProfile != null)
            _buildListTile(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: onProfile,
            ),

          _buildDivider(),

          // About
          if (onAbout != null)
            _buildListTile(
              icon: Icons.info_outline,
              label: 'About',
              onTap: onAbout,
            ),

          // Settings
          if (onSettings != null)
            _buildListTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: onSettings,
            ),

          // Terms
          if (onTerms != null)
            _buildListTile(
              icon: Icons.article_outlined,
              label: 'Terms & Conditions',
              onTap: onTerms,
            ),

          // Privacy
          if (onPrivacy != null)
            _buildListTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: onPrivacy,
            ),

          // Contact
          if (onContact != null)
            _buildListTile(
              icon: Icons.mail_outline,
              label: 'Contact Us',
              onTap: onContact,
            ),

          // Additional items
          if (additionalItems != null)
            ...additionalItems!.map(
              (item) => _buildListTile(
                icon: item.icon,
                label: item.label,
                onTap: item.onTap,
              ),
            ),

          _buildDivider(),

          // Logout
          if (onLogout != null)
            _buildListTile(
              icon: Icons.logout,
              label: 'Logout',
              onTap: onLogout,
              color: AppColors.error,
            ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    final textColor = color ?? Colors.grey[400];
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(label, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.grey[800]);
  }
}

/// Menu item for drawer
class DrawerMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const DrawerMenuItem({required this.icon, required this.label, this.onTap});
}
