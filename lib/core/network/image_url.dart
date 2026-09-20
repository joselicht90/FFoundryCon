/// Construye la URL de una imagen de Foundry. Las rutas relativas
/// (`ddb-images/...`, `worlds/...`) se sirven desde el reader (`/img/<path>`).
/// Las absolutas (`http...`) se devuelven tal cual. Los iconos del core de
/// Foundry (`icons/...`) no están en el volumen → devolvemos null (cae al
/// placeholder).
String? foundryImageUrl(String? base, String? img) {
  if (img == null || img.isEmpty) return null;
  if (img.startsWith('http')) return img;
  if (img.startsWith('icons/')) return null;
  if (base == null || base.isEmpty) return null;
  return '$base/img/$img';
}
