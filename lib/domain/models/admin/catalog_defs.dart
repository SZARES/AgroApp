import 'catalog_def.dart';
import 'field_def.dart';

/// One entry of the admin section switcher.
class AdminSection {
  const AdminSection({
    required this.id,
    required this.title,
    this.catalogs = const [],
  });

  final String id;
  final String title;

  /// Catalogs edited in this section; empty for users and audit.
  final List<CatalogDef> catalogs;

  bool get isCatalog => catalogs.isNotEmpty;
}

const _code = FieldDef(
  column: 'code',
  label: 'Código',
  required: true,
  hint: 'Identificador corto, sin repetir',
);
const _name = FieldDef(column: 'name', label: 'Nombre', required: true);

/// Registry of every configurable catalog. Nothing is hardcoded in the app:
/// these definitions only describe how to edit what the backend stores.
abstract final class CatalogDefs {
  static const zones = CatalogDef(
    id: 'zones',
    table: 'zones',
    title: 'Zonas',
    singular: 'zona',
    fields: [_code, _name],
    subtitleColumns: ['code'],
  );

  static const communities = CatalogDef(
    id: 'communities',
    table: 'communities',
    title: 'Comunidades',
    singular: 'comunidad',
    fields: [
      FieldDef(
        column: 'zone_id',
        label: 'Zona',
        kind: FieldKind.reference,
        required: true,
        referenceTable: 'zones',
      ),
      _name,
    ],
    subtitleColumns: ['zone_id'],
  );

  static const crops = CatalogDef(
    id: 'crops',
    table: 'crops',
    title: 'Cultivos',
    singular: 'cultivo',
    fields: [_code, _name],
    subtitleColumns: ['code'],
    allowedUnits: AllowedUnitsJoin(
      table: 'crop_harvest_units',
      ownerColumn: 'crop_id',
      label: 'Unidades de cosecha permitidas',
    ),
  );

  static const activityTypes = CatalogDef(
    id: 'activity_types',
    table: 'activity_types',
    title: 'Tipos de actividad',
    singular: 'tipo de actividad',
    fields: [
      _code,
      _name,
      FieldDef(
        column: 'requires_product',
        label: 'Pide un producto',
        kind: FieldKind.bool,
      ),
      FieldDef(
        column: 'requires_pruning_type',
        label: 'Pide un tipo de poda',
        kind: FieldKind.bool,
      ),
    ],
    subtitleColumns: ['code'],
    allowedUnits: AllowedUnitsJoin(
      table: 'activity_type_units',
      ownerColumn: 'activity_type_id',
      label: 'Unidades permitidas para esta actividad',
    ),
  );

  static const unitCategories = [
    FieldOption('weight', 'Peso'),
    FieldOption('volume', 'Volumen'),
    FieldOption('container', 'Envase'),
    FieldOption('productive', 'Productiva'),
    FieldOption('area', 'Área'),
    FieldOption('labor', 'Mano de obra'),
    FieldOption('irrigation', 'Riego'),
    FieldOption('other', 'Otra'),
  ];

  static const units = CatalogDef(
    id: 'units',
    table: 'units',
    title: 'Unidades',
    singular: 'unidad',
    fields: [
      _name,
      FieldDef(column: 'abbreviation', label: 'Abreviatura', required: true),
      FieldDef(
        column: 'category',
        label: 'Categoría',
        kind: FieldKind.dropdown,
        required: true,
        options: unitCategories,
      ),
    ],
    subtitleColumns: ['abbreviation', 'category'],
  );

  static const products = CatalogDef(
    id: 'products',
    table: 'products',
    title: 'Productos',
    singular: 'producto',
    fields: [
      _name,
      FieldDef(
        column: 'category',
        label: 'Categoría',
        required: true,
        hint: 'Por ejemplo: fertilizante',
      ),
      FieldDef(
        column: 'form',
        label: 'Presentación',
        required: true,
        hint: 'Por ejemplo: líquido',
      ),
    ],
    subtitleColumns: ['category', 'form'],
    allowedUnits: AllowedUnitsJoin(
      table: 'product_units',
      ownerColumn: 'product_id',
      label: 'Unidades permitidas para este producto',
    ),
  );

  static const symptoms = CatalogDef(
    id: 'symptom_types',
    table: 'symptom_types',
    title: 'Síntomas',
    singular: 'síntoma',
    fields: [_code, _name],
    subtitleColumns: ['code'],
  );

  static const pruningTypes = CatalogDef(
    id: 'pruning_types',
    table: 'pruning_types',
    title: 'Tipos de poda',
    singular: 'tipo de poda',
    fields: [_code, _name],
    subtitleColumns: ['code'],
  );

  static const assistanceCategories = CatalogDef(
    id: 'assistance_categories',
    table: 'assistance_categories',
    title: 'Categorías',
    singular: 'categoría de asistencia',
    fields: [_code, _name],
    subtitleColumns: ['code'],
  );

  static const assistanceSubtypes = CatalogDef(
    id: 'assistance_subtypes',
    table: 'assistance_subtypes',
    title: 'Subtipos',
    singular: 'subtipo de asistencia',
    fields: [
      FieldDef(
        column: 'category_id',
        label: 'Categoría',
        kind: FieldKind.reference,
        required: true,
        referenceTable: 'assistance_categories',
      ),
      _code,
      _name,
    ],
    subtitleColumns: ['category_id'],
  );

  static const expenseCategories = CatalogDef(
    id: 'expense_categories',
    table: 'expense_categories',
    title: 'Categorías de gasto',
    singular: 'categoría de gasto',
    fields: [_code, _name],
    subtitleColumns: ['code'],
  );

  static const buyers = CatalogDef(
    id: 'buyers',
    table: 'buyers',
    title: 'Acopiadores',
    singular: 'acopiador',
    fields: [
      _name,
      FieldDef(column: 'type', label: 'Tipo'),
      FieldDef(column: 'location', label: 'Ubicación'),
      FieldDef(
        column: 'zone_id',
        label: 'Zona',
        kind: FieldKind.reference,
        referenceTable: 'zones',
      ),
      FieldDef(column: 'phone', label: 'Teléfono'),
    ],
    subtitleColumns: ['type', 'location'],
  );

  static const referencePrices = CatalogDef(
    id: 'reference_prices',
    table: 'reference_prices',
    title: 'Precios de referencia',
    singular: 'precio de referencia',
    titleColumn: 'crop_id',
    subtitleColumns: ['price', 'currency', 'unit_id'],
    fields: [
      FieldDef(
        column: 'crop_id',
        label: 'Cultivo',
        kind: FieldKind.reference,
        required: true,
        referenceTable: 'crops',
      ),
      FieldDef(
        column: 'unit_id',
        label: 'Unidad',
        kind: FieldKind.reference,
        required: true,
        referenceTable: 'units',
      ),
      FieldDef(
        column: 'price',
        label: 'Precio',
        kind: FieldKind.number,
        required: true,
        positive: true,
      ),
      FieldDef(column: 'currency', label: 'Moneda', hint: 'PEN'),
      FieldDef(
        column: 'valid_from',
        label: 'Vigente desde',
        kind: FieldKind.date,
        required: true,
      ),
      FieldDef(
        column: 'valid_to',
        label: 'Vigente hasta',
        kind: FieldKind.date,
      ),
      FieldDef(column: 'notes', label: 'Notas', multiline: true),
    ],
  );

  static const unitEquivalences = CatalogDef(
    id: 'unit_equivalences',
    table: 'unit_equivalences',
    title: 'Equivalencias de unidades',
    singular: 'equivalencia',
    titleColumn: 'unit_id',
    subtitleColumns: ['crop_id', 'kg_per_unit'],
    hasActive: false,
    hasSortOrder: false,
    stampsValidation: true,
    fields: [
      FieldDef(
        column: 'crop_id',
        label: 'Cultivo (opcional)',
        kind: FieldKind.reference,
        referenceTable: 'crops',
      ),
      FieldDef(
        column: 'unit_id',
        label: 'Unidad',
        kind: FieldKind.reference,
        required: true,
        referenceTable: 'units',
      ),
      FieldDef(
        column: 'kg_per_unit',
        label: 'Kilos por unidad',
        kind: FieldKind.number,
        required: true,
        positive: true,
      ),
      FieldDef(
        column: 'validated',
        label: 'Validada (solo las validadas se usan para convertir a kilos)',
        kind: FieldKind.bool,
      ),
      FieldDef(column: 'notes', label: 'Notas', multiline: true),
    ],
  );

  static const settings = CatalogDef(
    id: 'app_settings',
    table: 'app_settings',
    title: 'Configuración',
    singular: 'configuración',
    idColumn: 'key',
    titleColumn: 'key',
    subtitleColumns: ['description'],
    hasActive: false,
    hasSortOrder: false,
    fields: [
      FieldDef(
        column: 'key',
        label: 'Clave',
        required: true,
        hint: 'No se puede cambiar después de crearla',
      ),
      FieldDef(
        column: 'value',
        label: 'Valor (JSON)',
        kind: FieldKind.json,
        required: true,
        multiline: true,
      ),
      FieldDef(column: 'description', label: 'Descripción', multiline: true),
    ],
  );

  static const all = <CatalogDef>[
    zones,
    communities,
    crops,
    activityTypes,
    units,
    products,
    symptoms,
    pruningTypes,
    assistanceCategories,
    assistanceSubtypes,
    expenseCategories,
    buyers,
    referencePrices,
    unitEquivalences,
    settings,
  ];

  /// Section switcher of the admin module, in display order.
  static const sections = <AdminSection>[
    AdminSection(id: 'users', title: 'Usuarios'),
    AdminSection(
      id: 'zones',
      title: 'Zonas y comunidades',
      catalogs: [zones, communities],
    ),
    AdminSection(id: 'crops', title: 'Cultivos', catalogs: [crops]),
    AdminSection(
      id: 'activity_types',
      title: 'Tipos de actividad',
      catalogs: [activityTypes],
    ),
    AdminSection(id: 'units', title: 'Unidades', catalogs: [units]),
    AdminSection(id: 'products', title: 'Productos', catalogs: [products]),
    AdminSection(id: 'symptoms', title: 'Síntomas', catalogs: [symptoms]),
    AdminSection(
      id: 'pruning_types',
      title: 'Tipos de poda',
      catalogs: [pruningTypes],
    ),
    AdminSection(
      id: 'assistance',
      title: 'Tipos de asistencia',
      catalogs: [assistanceCategories, assistanceSubtypes],
    ),
    AdminSection(
      id: 'expenses',
      title: 'Gastos',
      catalogs: [expenseCategories],
    ),
    AdminSection(id: 'buyers', title: 'Acopiadores', catalogs: [buyers]),
    AdminSection(id: 'prices', title: 'Precios', catalogs: [referencePrices]),
    AdminSection(
      id: 'equivalences',
      title: 'Equivalencias',
      catalogs: [unitEquivalences],
    ),
    AdminSection(id: 'settings', title: 'Configuración', catalogs: [settings]),
    AdminSection(id: 'audit', title: 'Auditoría'),
  ];

  static AdminSection get zonesSection =>
      sections.firstWhere((s) => s.id == 'zones');
  static AdminSection get cropsSection =>
      sections.firstWhere((s) => s.id == 'crops');
  static AdminSection get activityTypesSection =>
      sections.firstWhere((s) => s.id == 'activity_types');
  static AdminSection get pruningTypesSection =>
      sections.firstWhere((s) => s.id == 'pruning_types');
}

