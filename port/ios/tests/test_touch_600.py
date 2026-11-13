"""Checks independent size controls against the real Swift layout model.

The iOS app's SwiftUI/UIKit integration still requires an Xcode/device run.
On Linux the import of CoreGraphics is removed from a temporary test copy
because Foundation already exports CGSize and CGRect.
"""
import pathlib
import platform
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
LAUNCHER = ROOT / 'port/ios/launcher'
SWIFTC = shutil.which('swiftc')

HARNESS = '''import Foundation
@main struct Touch600Tests {
    static func main() {
        for mode in TouchLayoutOrientation.allCases {
            var layout = TouchLayout.defaults(mode)
            let cross = layout.controls.firstIndex { $0.slot == .cross }!
            let circle = layout.controls.firstIndex { $0.slot == .circle }!
            layout.controls[cross].scale = 6.0
            layout.controls[circle].scale = 0.25
            let sanitized = layout.sanitized(mode)
            assert(sanitized.controls[cross].scale == 6.0)
            assert(sanitized.controls[circle].scale == 0.25)
            assert(sanitized.controls.first { $0.slot == .square }!.scale == 1)
            assert(sanitized.controls[cross].size(fit: 1).width == 300)
            assert(sanitized.controls[circle].size(fit: 1).width == 12.5)
            assert(TouchControlPlacement.limitedCenter(140, item: 310, canvas: 300) == 140)
            assert(TouchControlPlacement.limitedCenter(320, item: 310, canvas: 300) == 300)
            assert(TouchControlPlacement.limitedCenter(5, item: 50, canvas: 300) == 25)
            layout.baseScale = 1.8
            assert(layout.controls[cross].size(fit: 1, baseScale: layout.baseScale).width == 540)
            layout.baseScale = 0.1
            assert(layout.controls[circle].size(fit: 1, baseScale: layout.baseScale).width == 1.25)
            layout.controls[cross].scale = 20.0
            assert(layout.sanitized(mode).controls[cross].scale == 6.0)
            layout.controls[circle].scale = Double.nan
            assert(layout.sanitized(mode).controls[circle].scale == 1.0)
            let defaultLayout = TouchLayout.defaults(mode)
            assert(defaultLayout.controls.allSatisfy { $0.scale == 1 })
            let pad = TouchLayout.ipadDefaults(mode)
            assert(pad.hasEssentialControls)
            assert(pad.baseScale == 1.25)
            assert(pad.controls.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
            assert(pad.controls.first { $0.slot == .stick }!.size(fit: 1, baseScale: pad.baseScale).width == 162.5)
            let screen = mode == .portrait ? CGSize(width: 768, height: 1024) : CGSize(width: 1024, height: 768)
            let viewport = TouchLayoutViewport(size: screen)
            let canvas = viewport.contentRect.size
            let fit = mode.fit(in: canvas) * CGFloat(pad.baseScale)
            let frames = pad.controls.filter { $0.visible }.map { control -> CGRect in
                let bounds = control.size(fit: fit)
                let cx = TouchControlPlacement.limitedCenter(CGFloat(control.x) * canvas.width,
                                                              item: bounds.width, canvas: canvas.width)
                let cy = TouchControlPlacement.limitedCenter(CGFloat(control.y) * canvas.height,
                                                              item: bounds.height, canvas: canvas.height)
                return CGRect(x: cx - bounds.width / 2, y: cy - bounds.height / 2,
                              width: bounds.width, height: bounds.height)
            }
            for i in frames.indices {
                for j in frames.indices where j > i {
                    assert(!frames[i].intersects(frames[j]), "Overlapping iPad defaults: \\(i), \\(j)")
                }
            }
            var configuration = TouchLayoutConfiguration()
            configuration[mode, pad: true].controls[cross].scale = 5.5
            assert(configuration[mode, pad: true].controls[cross].scale == 5.5)
            assert(configuration[mode, pad: false].controls[cross].scale == 1.0)
            var oldPadCustomized = TouchLayout.defaults(mode)
            oldPadCustomized.controls[cross].scale = 1.7
            assert(TouchLayoutConfiguration.padFallback(previous: oldPadCustomized, orientation: mode, isPad: true) == oldPadCustomized)
            assert(TouchLayoutConfiguration.padFallback(previous: TouchLayout.defaults(mode), orientation: mode, isPad: true) == pad)
            assert(TouchLayoutConfiguration.padFallback(previous: oldPadCustomized, orientation: mode, isPad: false) == pad)
            let oldJSON = try! JSONEncoder().encode(configuration)
            var archive = try! JSONSerialization.jsonObject(with: oldJSON) as! [String: Any]
            archive.removeValue(forKey: "ipadPortrait")
            archive.removeValue(forKey: "ipadLandscape")
            let legacyV2 = try! JSONSerialization.data(withJSONObject: archive)
            let upgraded = try! JSONDecoder().decode(TouchLayoutConfiguration.self, from: legacyV2)
            assert(upgraded[mode, pad: true] == TouchLayout.ipadDefaults(mode))
        }
    }
}'''

class Touch600Checks(unittest.TestCase):
    @unittest.skipUnless(SWIFTC, 'requires Swift compiler')
    def test_individual_sizes_bounds_and_orientation_with_production_swift_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp)
            source = (LAUNCHER / 'TouchLayout.swift').read_text()
            if platform.system() != 'Darwin':
                source = source.replace('import CoreGraphics', '// Foundation exports geometry types on Linux')
            (path / 'TouchLayout.swift').write_text(source)
            (path / 'Tests.swift').write_text(HARNESS)
            subprocess.run([SWIFTC, '-swift-version', '5', str(path / 'TouchLayout.swift'),
                            str(path / 'Tests.swift'), '-o', str(path / 'test_touch')],
                           check=True, timeout=75)
            subprocess.run([str(path / 'test_touch')], check=True, timeout=15)

    def test_editor_targets_selected_control_and_persists_layout(self):
        ui = (LAUNCHER / 'ControlsCustomizationView.swift').read_text()
        store = (LAUNCHER / 'TouchLayoutStore.swift').read_text()
        surface = (LAUNCHER / 'TouchControlSurface.swift').read_text()
        self.assertIn('sizeAdjustment(index)', ui)
        self.assertIn('range: TouchControlPlacement.minimumScale...TouchControlPlacement.maximumScale', ui)
        self.assertIn('layout.controls[index].scale', ui)
        self.assertIn('touch_layouts_v2.json', store)
        self.assertIn('saved.scale.isFinite', (LAUNCHER / 'TouchLayout.swift').read_text())
        self.assertIn('baseScale: layout.baseScale', surface)
        self.assertIn('TouchLayoutDevice.isPad', (LAUNCHER / 'TouchLayout.swift').read_text())
        self.assertIn('nearestTarget', (LAUNCHER / 'ImmediateTouchInput.swift').read_text())

if __name__ == '__main__':
    unittest.main()
