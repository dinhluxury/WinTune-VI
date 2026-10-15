using System;
using System.Windows;
using System.Windows.Controls;

namespace WinTune {
    // Independent category columns keep small cards at their natural height.
    public sealed class CompactGroupsPanel : Panel {
        public static readonly DependencyProperty ColumnWidthProperty = DependencyProperty.Register(
            "ColumnWidth", typeof(double), typeof(CompactGroupsPanel),
            new FrameworkPropertyMetadata(300.0, FrameworkPropertyMetadataOptions.AffectsMeasure));
        public double ColumnWidth { get { return (double)GetValue(ColumnWidthProperty); } set { SetValue(ColumnWidthProperty, value); } }
        double SlotWidth { get { return Math.Max(248.0, ColumnWidth + 8.0); } }
        int Columns(double width) {
            if (double.IsInfinity(width) || double.IsNaN(width)) return 1;
            return Math.Max(1, Math.Min(3, (int)Math.Floor((width + 0.1) / SlotWidth)));
        }
        static int Shortest(double[] heights) {
            int index = 0;
            for (int i = 1; i < heights.Length; i++) if (heights[i] < heights[index]) index = i;
            return index;
        }
        protected override Size MeasureOverride(Size available) {
            int columns = Columns(available.Width); double[] heights = new double[columns];
            foreach (UIElement child in InternalChildren) {
                if (child == null || child.Visibility == Visibility.Collapsed) continue;
                child.Measure(new Size(SlotWidth, double.PositiveInfinity));
                heights[Shortest(heights)] += child.DesiredSize.Height;
            }
            double height = 0; foreach (double h in heights) height = Math.Max(height, h);
            return new Size(double.IsInfinity(available.Width) ? columns * SlotWidth : available.Width, height);
        }
        protected override Size ArrangeOverride(Size finalSize) {
            int columns = Columns(finalSize.Width); double[] heights = new double[columns];
            foreach (UIElement child in InternalChildren) {
                if (child == null || child.Visibility == Visibility.Collapsed) continue;
                int column = Shortest(heights);
                child.Arrange(new Rect(column * SlotWidth, heights[column], SlotWidth, child.DesiredSize.Height));
                heights[column] += child.DesiredSize.Height;
            }
            return finalSize;
        }
    }
}
