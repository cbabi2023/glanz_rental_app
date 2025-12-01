import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/customers_provider.dart';
import '../../models/customer.dart';
import '../../core/supabase_client.dart';
import 'dart:io';

/// Create Customer Screen
/// 
/// Modern, attractive form to create a new customer with ID proof upload
class CreateCustomerScreen extends ConsumerStatefulWidget {
  const CreateCustomerScreen({super.key});

  @override
  ConsumerState<CreateCustomerScreen> createState() =>
      _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends ConsumerState<CreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _idProofNumberController = TextEditingController();

  IdProofType? _selectedIdProofType;
  File? _idProofFrontImage;
  File? _idProofBackImage;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idProofNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, bool isFront) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        setState(() {
          if (isFront) {
            _idProofFrontImage = File(image.path);
          } else {
            _idProofBackImage = File(image.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final supabase = SupabaseService.client;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = DateTime.now().microsecondsSinceEpoch.toString().substring(0, 6);
      final uniqueFileName = '$timestamp-$random.jpg';
      final filePath = 'customer-id-proofs/$uniqueFileName';

      await supabase.storage.from('customer-id-proofs').upload(
            filePath,
            imageFile,
          );

      final url = supabase.storage
          .from('customer-id-proofs')
          .getPublicUrl(filePath);

      print('Image uploaded successfully: $url');
      return url;
    } catch (e) {
      print('Error uploading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 10) {
      setState(() {
        _errorMessage = 'Phone number must be exactly 10 digits';
      });
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? idProofFrontUrl;
      String? idProofBackUrl;

      if (_idProofFrontImage != null) {
        try {
          idProofFrontUrl = await _uploadImage(_idProofFrontImage!);
          if (idProofFrontUrl == null || idProofFrontUrl.isEmpty) {
            throw Exception('Failed to upload front image: No URL returned');
          }
        } catch (e) {
          throw Exception('Failed to upload front image: $e');
        }
      }

      if (_idProofBackImage != null) {
        try {
          idProofBackUrl = await _uploadImage(_idProofBackImage!);
          if (idProofBackUrl == null || idProofBackUrl.isEmpty) {
            throw Exception('Failed to upload back image: No URL returned');
          }
        } catch (e) {
          throw Exception('Failed to upload back image: $e');
        }
      }

      final customersService = ref.read(customersServiceProvider);
      await customersService.createCustomer(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: null,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        idProofType: _selectedIdProofType,
        idProofNumber: _idProofNumberController.text.trim().isEmpty
            ? null
            : _idProofNumberController.text.trim(),
        idProofFrontUrl: idProofFrontUrl,
        idProofBackUrl: idProofBackUrl,
      );

      ref.invalidate(customersProvider(CustomersParams()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create customer: ${e.toString()}';
      });
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Modern Header
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0B63FF),
                      Color(0xFF0052D4),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.person_add,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'New Customer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add customer details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Card
                    _SectionCard(
                      title: 'Basic Information',
                      icon: Icons.person_outline,
                      children: [
                        _ModernTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter customer name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ModernTextField(
                          controller: _phoneController,
                          label: 'Phone Number',
                          hint: '10 digits',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            final digits = value.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 10) {
                              return 'Phone number must be 10 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _ModernTextField(
                          controller: _addressController,
                          label: 'Address',
                          hint: 'Enter customer address (optional)',
                          prefixIcon: Icons.location_on_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ID Proof Section Card
                    _SectionCard(
                      title: 'ID Proof',
                      icon: Icons.verified_outlined,
                      subtitle: 'Optional',
                      children: [
                        _ModernDropdown<IdProofType>(
                          value: _selectedIdProofType,
                          label: 'ID Proof Type',
                          hint: 'Select ID proof type',
                          icon: Icons.credit_card_outlined,
                          items: IdProofType.allValues.map((type) {
                            return DropdownMenuItem(
                              value: IdProofType.fromString(type),
                              child: Text(_formatIdProofType(type)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedIdProofType = value;
                              if (value == null) {
                                _idProofNumberController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        _ModernTextField(
                          controller: _idProofNumberController,
                          label: 'ID Proof Number',
                          hint: 'Enter ID proof number',
                          prefixIcon: Icons.numbers_outlined,
                          enabled: _selectedIdProofType != null,
                        ),
                        const SizedBox(height: 20),

                        // ID Proof Images
                        Row(
                          children: [
                            Expanded(
                              child: _ImageUploadCard(
                                label: 'Front Side',
                                image: _idProofFrontImage,
                                onTap: () => _showImageSourceDialog(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ImageUploadCard(
                                label: 'Back Side',
                                image: _idProofBackImage,
                                onTap: () => _showImageSourceDialog(false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Error Message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_errorMessage != null) const SizedBox(height: 16),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Create Customer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceDialog(bool isFront) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: const Color(0xFF0B63FF),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera, isFront);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery, isFront);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatIdProofType(String type) {
    switch (type) {
      case 'aadhar':
        return 'Aadhar Card';
      case 'passport':
        return 'Passport';
      case 'voter':
        return 'Voter ID';
      case 'others':
        return 'Other ID';
      default:
        return type.toUpperCase();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF0B63FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int? maxLines;
  final bool enabled;

  const _ModernTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: enabled ? const Color(0xFF0F1724) : Colors.grey.shade600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: enabled ? const Color(0xFF0B63FF) : Colors.grey.shade400),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B63FF), width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade500, width: 2),
        ),
        counterText: '',
      ),
    );
  }
}

class _ModernDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const _ModernDropdown({
    required this.value,
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF0B63FF)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B63FF), width: 2),
        ),
      ),
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF0F1724),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  final String label;
  final File? image;
  final VoidCallback onTap;

  const _ImageUploadCard({
    required this.label,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: image != null ? const Color(0xFF0B63FF) : Colors.grey.shade300,
            width: image != null ? 2 : 1,
          ),
        ),
        child: image != null
            ? Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      image!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 16,
                        color: const Color(0xFF0B63FF),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to add',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
