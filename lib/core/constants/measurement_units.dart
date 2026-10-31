class MeasurementUnit {
  final String value;
  final String label;

  const MeasurementUnit(this.value, this.label);
}

const List<MeasurementUnit> measurementUnits = [
  MeasurementUnit('g', 'Grams (g)'),
  MeasurementUnit('kg', 'Kilograms (kg)'),
  MeasurementUnit('mg', 'Milligrams (mg)'),
  MeasurementUnit('ml', 'Milliliters (ml)'),
  MeasurementUnit('l', 'Liters (l)'),
  MeasurementUnit('pcs', 'Pieces (pcs)'),
  MeasurementUnit('tbsp', 'Tablespoon (tbsp)'),
  MeasurementUnit('tsp', 'Teaspoon (tsp)'),
  MeasurementUnit('cup', 'Cup'),
  MeasurementUnit('slice', 'Slice'),
  MeasurementUnit('pinch', 'Pinch'),
  MeasurementUnit('clove', 'Clove'),
  MeasurementUnit('serving', 'Serving'),
];
