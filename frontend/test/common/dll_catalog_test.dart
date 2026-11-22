import 'package:dlss_updater/src/ui/common/dll_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every backend catalog id has its own display label', () {
    // Kept in sync with backend/internal/scan/catalog.go. A new id there must
    // get a label here instead of falling back to the raw token.
    const ids = [
      'dlss',
      'dlss_g',
      'dlss_d',
      'dlss_nr',
      'xess',
      'xess_dx11',
      'xess_fg',
      'xell',
      'streamline_common',
      'streamline_dlss',
      'streamline_dlss_g',
      'streamline_interposer',
      'streamline_pcl',
      'streamline_reflex',
      'streamline_directsr',
      'streamline_dlss_d',
      'streamline_nis',
      'fsr_vk',
      'fsr_dx12',
      'fsr4_upscaler_dx12',
      'fsr4_framegeneration_dx12',
      'fsr4_loader_dx12',
      'fsr4_upscaler_vk',
      'fsr4_framegeneration_vk',
      'fsr4_loader_vk',
      'fsr_denoiser_dx12',
      'fsr_radiancecache_dx12',
    ];

    final seen = <String>{};
    for (final id in ids) {
      final label = dllTypeLabel(id);
      expect(
        label,
        isNot(id),
        reason: '$id must have a catalog label, not the raw id',
      );
      expect(label, isNotEmpty);
      expect(seen.add(label), isTrue, reason: '$id reuses the label $label');
    }
  });

  test('known labels match the games and backups copy', () {
    expect(dllTypeLabel('dlss'), 'DLSS');
    expect(dllTypeLabel('dlss_g'), 'DLSS Frame Generation');
    expect(dllTypeLabel('xess'), 'XeSS');
    expect(dllTypeLabel('fsr_dx12'), 'FSR DX12');
  });

  test('an unknown id still reads as words and an empty id is generic', () {
    expect(dllTypeLabel('future_upscaler_dx12'), 'Future Upscaler Dx12');
    expect(dllTypeLabel(''), 'Unknown DLL');
    expect(dllTypeLabel('___'), 'Unknown DLL');
  });
}
