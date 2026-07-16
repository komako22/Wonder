using System.Windows;
using System.Windows.Interop;
using System.Windows.Input;
using GlassTranslate.Windows.Interop;
using GlassTranslate.Windows.Models;
using GlassTranslate.Windows.Services;

namespace GlassTranslate.Windows.Views;

public partial class BubbleWindow : Window
{
    private readonly Action _clicked;

    public BubbleWindow(SelectionSnapshot selection, SettingsStore settings, Action clicked)
    {
        InitializeComponent();
        _clicked = clicked;
        Width = 60 * settings.BubbleScale;
        Height = 48 * settings.BubbleScale;
        BubbleBorder.Width = 38 * settings.BubbleScale;
        BubbleBorder.Height = 38 * settings.BubbleScale;
        BubbleBorder.CornerRadius = new CornerRadius(10 * settings.BubbleScale);
        SourceInitialized += (_, _) => WindowEffects.ApplyNoActivate(new WindowInteropHelper(this).Handle);
        PositionNear(selection.ScreenRect, settings.BubblePosition);
    }

    private void PositionNear(Rect rect, BubblePosition position)
    {
        if (position == BubblePosition.Pointer)
        {
            var pointer = System.Windows.Forms.Cursor.Position;
            var anchor = DisplayCoordinates.ToDip(pointer.X + 8, pointer.Y + 8);
            Left = anchor.X;
            Top = anchor.Y;
            return;
        }
        var edge = position == BubblePosition.Below ? rect.Bottom + 6 : rect.Top - 6;
        var selectionAnchor = DisplayCoordinates.ToDip(rect.Left + rect.Width / 2, edge);
        Left = selectionAnchor.X - Width / 2;
        Top = position == BubblePosition.Below ? selectionAnchor.Y : selectionAnchor.Y - Height;
    }

    private void Bubble_OnMouseLeftButtonUp(object sender, MouseButtonEventArgs e)
    {
        e.Handled = true;
        _clicked();
    }
}
