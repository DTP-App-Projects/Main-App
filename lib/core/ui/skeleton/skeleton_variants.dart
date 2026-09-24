import 'package:flutter/material.dart';

import 'skeleton.dart';

/// A list of rows. Matches the shape of a document/supplier/order list: a
/// leading square, two lines of text, a trailing amount.
class ListSkeleton extends StatelessWidget {
  final int rows;
  final EdgeInsetsGeometry padding;

  const ListSkeleton({
    super.key,
    this.rows = 6,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
  });

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: ListView.separated(
          padding: padding,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows,
          separatorBuilder: (_, _) => const SizedBox(height: 20),
          itemBuilder: (_, index) => const _ListRowSkeleton(),
        ),
      );
}

class _ListRowSkeleton extends StatelessWidget {
  const _ListRowSkeleton();

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 44, height: 44, radius: BorderRadius.all(Radius.circular(999))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton.line(widthFactor: 0.62, height: 14),
                SizedBox(height: 8),
                Skeleton.line(widthFactor: 0.38, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Skeleton(width: 56, height: 14),
        ],
      );
}

/// The four KPI tiles on either home screen.
class KpiGridSkeleton extends StatelessWidget {
  const KpiGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: GridView.count(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(4, (_) => const Skeleton.box(height: 96)),
        ),
      );
}

/// A form: label + field pairs, then a submit button.
class FormSkeleton extends StatelessWidget {
  final int fields;

  const FormSkeleton({super.key, this.fields = 4});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields; i++) ...const [
                Skeleton.line(widthFactor: 0.28, height: 11),
                SizedBox(height: 8),
                Skeleton.box(height: 52),
                SizedBox(height: 18),
              ],
              const SizedBox(height: 8),
              const Skeleton.box(height: 52),
            ],
          ),
        ),
      );
}

/// A document detail: header block, a few facts, then a timeline.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Skeleton.box(height: 120),
              SizedBox(height: 20),
              Skeleton.line(widthFactor: 0.45, height: 14),
              SizedBox(height: 10),
              Skeleton.line(widthFactor: 0.80, height: 11),
              SizedBox(height: 10),
              Skeleton.line(widthFactor: 0.66, height: 11),
              SizedBox(height: 24),
              Skeleton.line(widthFactor: 0.30, height: 13),
              SizedBox(height: 14),
              Skeleton.box(height: 64),
              SizedBox(height: 12),
              Skeleton.box(height: 64),
            ],
          ),
        ),
      );
}

/// A product grid (shop feeds, favourites).
class GridSkeleton extends StatelessWidget {
  final int items;

  const GridSkeleton({super.key, this.items = 6});

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
        child: GridView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 210,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: items,
          itemBuilder: (_, _) => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Skeleton.box(height: double.infinity)),
              SizedBox(height: 10),
              Skeleton.line(widthFactor: 0.8),
              SizedBox(height: 8),
              Skeleton.line(widthFactor: 0.4),
            ],
          ),
        ),
      );
}
