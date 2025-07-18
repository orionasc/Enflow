import SwiftUI

/// Simple dotted overlay used to indicate forecasted energy segments.
struct DotPatternOverlay: View {
    var color: Color = .white
    var body: some View {
        GeometryReader { proxy in
            Canvas { ctx, size in
                let spacing: CGFloat = 4
                let radius: CGFloat = 1.5
                var y: CGFloat = radius
                while y < size.height {
                    var x: CGFloat = radius
                    while x < size.width {
                        let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.3)))
                        x += spacing
                    }
                    y += spacing
                }
            }
        }
    }
}

#if DEBUG
struct DotPatternOverlay_Previews: PreviewProvider {
    static var previews: some View {
        DotPatternOverlay(color: .orange)
            .frame(width: 100, height: 40)
            .background(Color.black)
    }
}
#endif
