import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final String appName;
  final String packageName;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const AppCard({
    super.key,
    required this.appName,
    required this.packageName,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.android)),
        title: Text(appName),
        subtitle: Text(packageName),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
