import 'package:flutter/material.dart';

class ModelLibrary extends StatelessWidget {
  const ModelLibrary({
    super.key,
    required this.paths,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onDemo,
    required this.fileCount,
  });

  final List<String> paths;
  final String? selected;
  final bool busy;
  final ValueChanged<String> onSelected;
  final VoidCallback onDemo;
  final int fileCount;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff131d24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Text(
            'MODELS · ${paths.length}',
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.5,
              color: Color(0xffb8ed83),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(
            'Drop a folder or XML files anywhere.\nInclude meshes and other referenced files.',
            style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.6),
          ),
        ),
        if (fileCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              '$fileCount imported files',
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ),
        const Divider(),
        Expanded(
          child: paths.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'Your XML models will appear here.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: paths.length,
                  itemBuilder: (context, index) {
                    final path = paths[index];
                    return ListTile(
                      key: ValueKey('model:$path'),
                      dense: true,
                      selected: selected == path,
                      textColor: Colors.white70,
                      iconColor: Colors.white54,
                      selectedColor: const Color(0xffb8ed83),
                      selectedTileColor: const Color(0x223f8c63),
                      leading: Icon(
                        selected == path
                            ? Icons.radio_button_checked
                            : Icons.description_outlined,
                        size: 18,
                      ),
                      title: Text(path, style: const TextStyle(fontSize: 12)),
                      enabled: !busy,
                      onTap: () => onSelected(path),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: OutlinedButton.icon(
            onPressed: busy ? null : onDemo,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xffb8ed83),
            ),
            icon: const Icon(Icons.science_outlined, size: 18),
            label: const Text('Physics lab demo'),
          ),
        ),
      ],
    ),
  );
}
