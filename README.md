# Agustinita Creator

App de Agustinita Papelería para diseñar **agendas y post-its personalizados con IA** y exportar PDF listo para imprimir. Flutter: Mac (.dmg) e iPad (.ipa).

## Cómo funciona
- **La IA (fal.ai / Flux) dibuja solo el arte**: marco y personaje del post-it, portada de la agenda y la conversión de una foto en personaje (Flux Kontext).
- **La app dibuja el papel con código**: calendarios, pautas, títulos, días, nombre y frase, con las medidas exactas de producción, sangrado y marcas de corte.

## Productos y medidas (de los PDF de producción)
- **Agenda anillada 15 mm, doble cara**: hoja carta horizontal, 2 páginas de 139,7 × 215,9 mm por cara, marco 120,3 × 185,9 mm, margen de anillos 15 mm. 24 hojas = 48 páginas. Portada aparte en hoja carta con marcas de corte.
- **Post-it cuadrado** 100 × 100 mm, 4 por carta · **horizontal** 150 × 90 mm, 2 por carta · **vertical** 70 × 150 mm, 3 por carta.

## Formularios
- **Agenda**: nombre, frase, estilo (kawaii / pastel / floral / gótico suave / anime / minimal), concepto (romántica, para profesora, enfermero…), indicaciones extra, foto opcional → personaje, año de los calendarios, lado del margen en el reverso.
- **Post-its**: estilo, concepto, título (Compras, Plan de comidas, Pendientes…), contenido (rayado, checklist, días de la semana, cuadrícula, punteado, liso), hojas a exportar.

## Dónde se ajusta cada cosa
- `lib/specs.dart` — medidas y secuencia de páginas de la agenda.
- `lib/theme_spec.dart` — paletas de cada estilo y su descripción para la IA.
- `lib/ai/prompts.dart` — receta de prompts.
- `lib/pdf/agenda_builder.dart` y `lib/pdf/postit_builder.dart` — dibujo de las páginas.
- `assets/fonts/` — fuentes (Poppins de momento; reemplazar por las de Agustinita).

## Compilar
GitHub Actions (`Build Agustinita Creator`) genera el `.dmg` (sin firmar: clic derecho → Abrir la primera vez) y el `.ipa` (Sideloadly). Localmente: `flutter create --platforms macos,ios --org cl.agustinita --project-name agustinita_creator .` y luego `flutter build macos` / `flutter build ipa`.

## Pendientes
- Fuentes reales de Agustinita y logo definitivo (el ícono actual es un placeholder rosado con "A").
- Editor de secuencia de páginas (hoy usa la combinación de la agenda de Agustina).
- Guardar "clientes" (nombre + foto + estilo) para repetir pedidos.
