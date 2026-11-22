/// Display names for the catalog ids `backend/internal/scan/catalog.go`
/// reports. Scan events and backup rows share this map, so a DLL type reads
/// the same in both destinations and no id is left unlabelled.
library;

const Map<String, String> _dllTypeLabels = {
  // NVIDIA DLSS
  'dlss': 'DLSS',
  'dlss_g': 'DLSS Frame Generation',
  'dlss_d': 'DLSS Ray Reconstruction',
  'dlss_nr': 'DLSS Neural Rendering',

  // Intel XeSS
  'xess': 'XeSS',
  'xess_dx11': 'XeSS DX11',
  'xess_fg': 'XeSS Frame Generation',
  'xell': 'XeLL',

  // NVIDIA Streamline
  'streamline': 'Streamline',
  'streamline_common': 'Streamline Common',
  'streamline_dlss': 'Streamline DLSS',
  'streamline_dlss_g': 'Streamline DLSS Frame Generation',
  'streamline_interposer': 'Streamline Interposer',
  'streamline_pcl': 'Streamline PCL',
  'streamline_reflex': 'Streamline Reflex',
  'streamline_directsr': 'Streamline DirectSR',
  'streamline_dlss_d': 'Streamline DLSS Ray Reconstruction',
  'streamline_nis': 'Streamline NIS',

  // AMD FidelityFX Super Resolution
  'fsr': 'FSR',
  'fsr_vk': 'FSR Vulkan',
  'fsr_dx12': 'FSR DX12',
  'fsr4_upscaler_dx12': 'FSR4 Upscaler DX12',
  'fsr4_framegeneration_dx12': 'FSR4 Frame Generation DX12',
  'fsr4_loader_dx12': 'FSR4 Loader DX12',
  'fsr4_upscaler_vk': 'FSR4 Upscaler Vulkan',
  'fsr4_framegeneration_vk': 'FSR4 Frame Generation Vulkan',
  'fsr4_loader_vk': 'FSR4 Loader Vulkan',
  'fsr_denoiser_dx12': 'FSR Denoiser DX12',
  'fsr_radiancecache_dx12': 'FSR Radiance Cache DX12',
};

/// Human-readable name for a stable lowercase catalog id.
///
/// An id this build does not know still renders readably: underscores become
/// spaces and each word is capitalised. An empty id is a generic label.
String dllTypeLabel(String type) {
  if (type.isEmpty) return 'Unknown DLL';
  final known = _dllTypeLabels[type];
  if (known != null) return known;
  final words = type.split('_').where((word) => word.isNotEmpty);
  if (words.isEmpty) return 'Unknown DLL';
  return words
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
