import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import '../models/category.dart';
import '../models/batch.dart';

class MedicineFormScreen extends StatefulWidget {
  final Medicine? medicine;

  const MedicineFormScreen({super.key, this.medicine});

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _stockController = TextEditingController();
  final _expiredDateController = TextEditingController();

  int? _selectedCategoryId;
  List<Category> categories = [];
  DateTime? _selectedExpiredDate;
  List<Batch> existingBatches = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.medicine != null) {
      _nameController.text = widget.medicine!.name;
      _priceController.text = widget.medicine!.price.toString();
      _selectedCategoryId = widget.medicine!.categoryId;
      _loadBatches();
    }
  }

  Future<void> _loadCategories() async {
    categories = await DatabaseHelper.instance.getCategories();
    setState(() {});
  }

  Future<void> _loadBatches() async {
    if (widget.medicine != null) {
      existingBatches = await DatabaseHelper.instance
          .getBatchesByMedicine(widget.medicine!.id!);
      setState(() {});
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        _selectedExpiredDate = date;
        _expiredDateController.text = '${date.day}/${date.month}/${date.year}';
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih kategori')),
        );
        return;
      }

      if (_selectedExpiredDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih tanggal kadaluarsa')),
        );
        return;
      }

      final price = double.parse(_priceController.text);
      final stock = int.parse(_stockController.text);

      if (widget.medicine == null) {
        // Insert medicine
        final medicine = Medicine(
          name: _nameController.text,
          categoryId: _selectedCategoryId!,
          price: price,
          stockTotal: stock,
        );
        final medicineId =
            await DatabaseHelper.instance.insertMedicine(medicine);

        // Insert batch
        final batch = Batch(
          medicineId: medicineId,
          batchNumber: _batchNumberController.text,
          stock: stock,
          expiredDate: _selectedExpiredDate!,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.insertBatch(batch);
        await DatabaseHelper.instance.updateMedicineStock(medicineId);
      } else {
        // Update medicine
        final medicine = Medicine(
          id: widget.medicine!.id,
          name: _nameController.text,
          categoryId: _selectedCategoryId!,
          price: price,
          stockTotal: widget.medicine!.stockTotal + stock,
        );
        await DatabaseHelper.instance.updateMedicine(medicine);

        // Add new batch
        final batch = Batch(
          medicineId: widget.medicine!.id!,
          batchNumber: _batchNumberController.text,
          stock: stock,
          expiredDate: _selectedExpiredDate!,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.insertBatch(batch);
        await DatabaseHelper.instance.updateMedicineStock(widget.medicine!.id!);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicine == null ? 'Tambah Obat' : 'Edit Obat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Obat',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.medication),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Nama obat harus diisi' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategoryId = value),
                validator: (value) => value == null ? 'Pilih kategori' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Harga',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty == true) {
                    return 'Harga harus diisi';
                  }
                  if (double.tryParse(value!) == null) {
                    return 'Harga tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _batchNumberController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Batch',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Nomor batch harus diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Jumlah Stok',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.inventory_2),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty == true) return 'Stok harus diisi';
                  if (int.tryParse(value!) == null) return 'Stok tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _expiredDateController,
                decoration: InputDecoration(
                  labelText: 'Tanggal Kadaluarsa',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.event),
                    onPressed: _selectDate,
                  ),
                ),
                readOnly: true,
                onTap: _selectDate,
                validator: (value) =>
                    value?.isEmpty == true ? 'Pilih tanggal kadaluarsa' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveMedicine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.medicine == null ? 'Simpan Obat' : 'Tambah Batch',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              if (existingBatches.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Batch Existing:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...existingBatches.map((batch) => Card(
                      child: ListTile(
                        title: Text('Batch: ${batch.batchNumber}'),
                        subtitle: Text('Stok: ${batch.stock}'),
                        trailing: Text(
                          'Exp: ${batch.expiredDate.day}/${batch.expiredDate.month}/${batch.expiredDate.year}',
                        ),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
