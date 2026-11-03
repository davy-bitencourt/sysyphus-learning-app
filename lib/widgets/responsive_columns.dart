import 'package:flutter/material.dart';

class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.spacing = 12,
    this.maxColumns = 3,
    this.minColumnWidth = 360,
  });

  final List<Widget> children;
  final double spacing;
  final int maxColumns;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = (constraints.maxWidth / minColumnWidth)
          .floor()
          .clamp(1, maxColumns);

      Widget stack(List<Widget> items) => Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                items[i],
              ],
            ],
          );

      if (cols == 1) return stack(children);

      // distribui os cards em rodízio: 0,1,2,0,1,2...
      final buckets = List.generate(cols, (_) => <Widget>[]);
      for (var i = 0; i < children.length; i++) {
        buckets[i % cols].add(children[i]);
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cols; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: stack(buckets[i])),
          ],
        ],
      );
    });
  }
}