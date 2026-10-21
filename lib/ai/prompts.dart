import '../theme_spec.dart';

/// Receta de prompts de Agustinita Creator.
/// Traduce estilo + concepto en instrucciones para Flux; nunca nombra marcas
/// ni personajes registrados: describe la estética.
class Prompts {
  static const _noText =
      'SIN NINGÚN TEXTO, letras, números ni logos en la imagen.';

  static String _concept(String concept) => concept.trim().isEmpty
      ? ''
      : 'TEMA: $concept. Que el personaje y los adornos reflejen ese tema (objetos, ropa y símbolos propios de ese tema).';

  /// Marco de post-it: borde ilustrado y centro claro para escribir.
  static String postitFrame({
    required StyleSpec style,
    required String concept,
    required String extra,
    required bool horizontal,
  }) {
    return '''
Marco decorativo para una nota adhesiva (post-it) ${horizontal ? 'horizontal' : 'vertical'}.
ESTÉTICA: ${style.aiPrompt}.
${_concept(concept)}
COMPOSICIÓN: el borde de la imagen está decorado (guirnaldas, flores, estrellas, cintas, pequeños detalles) y un personaje tierno asoma en la esquina inferior derecha. El CENTRO (70 % del área) es un espacio BLANCO completamente limpio y vacío para escribir a mano. Fondo blanco, estilo sticker de papelería, alta resolución, bordes nítidos.
${extra.trim().isEmpty ? '' : 'INDICACIONES EXTRA: $extra'}
$_noText
'''
        .trim();
  }

  /// Portada de agenda: arte a página completa con el tercio inferior más
  /// despejado para poner el nombre.
  static String agendaCover({
    required StyleSpec style,
    required String concept,
    required String extra,
    required bool hasCharacter,
  }) {
    return '''
Portada ilustrada para una agenda personal, formato vertical.
ESTÉTICA: ${style.aiPrompt}.
${_concept(concept)}
COMPOSICIÓN: ${hasCharacter ? 'el personaje protagonista (ver imagen de referencia) centrado en el tercio superior y medio, ' : 'un personaje tierno protagonista en el centro, '}rodeado de adornos del tema; el tercio inferior más despejado y de color suave para colocar un nombre después. Patrón de fondo sutil, colores armoniosos, estilo papelería premium, alta resolución.
${extra.trim().isEmpty ? '' : 'INDICACIONES EXTRA: $extra'}
$_noText
'''
        .trim();
  }

  /// Foto → personaje (Kontext). Mantiene rasgos reconocibles.
  static String photoToCharacter({
    required StyleSpec style,
    required String concept,
  }) {
    return '''
Convierte a la persona de la foto en un personaje ilustrado, manteniendo sus rasgos reconocibles (peinado, color de pelo, lentes si tiene, forma de cara, tono de piel, sonrisa).
ESTÉTICA: ${style.aiPrompt}.
${_concept(concept)}
Cuerpo completo o medio cuerpo, pose alegre, fondo blanco liso, estilo sticker con contorno limpio, alta resolución.
$_noText
'''
        .trim();
  }
}
