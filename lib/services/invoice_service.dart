import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart';
import '../models/order.dart';
import '../core/supabase_client.dart';
import '../core/logger.dart';

/// Invoice Service - Updated to match website design
///
/// Handles invoice PDF generation, viewing, sharing, and downloading
class InvoiceService {
  /// Load product image from URL
  static Future<pw.MemoryImage?> _loadProductImage(String imageUrl) async {
    if (imageUrl.isEmpty) return null;

    try {
      AppLogger.debug('Loading product image from URL: $imageUrl');
      final uri = Uri.parse(imageUrl);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final httpResponse = await request.close();

      if (httpResponse.statusCode == 200) {
        final bytes = <int>[];
        await for (final chunk in httpResponse) {
          bytes.addAll(chunk);
        }
        client.close();

        if (bytes.isNotEmpty) {
          AppLogger.success(
            'Successfully loaded product image (${bytes.length} bytes)',
          );
          return pw.MemoryImage(Uint8List.fromList(bytes));
        }
      }
      client.close();
    } catch (e) {
      AppLogger.error('Failed to load product image from URL', e);
    }

    return null;
  }

  /// Load logo image from user profile or assets
  static Future<pw.MemoryImage?> _loadLogoImage() async {
    // First, try to load from user profile company logo URL
    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        final response = await SupabaseService.client
            .from('profiles')
            .select('company_logo_url')
            .eq('id', user.id)
            .single();

        final logoUrl = response['company_logo_url']?.toString();
        if (logoUrl != null && logoUrl.isNotEmpty) {
          try {
            AppLogger.debug('Loading logo from profile URL: $logoUrl');
            final uri = Uri.parse(logoUrl);
            final client = HttpClient();
            final request = await client.getUrl(uri);
            final httpResponse = await request.close();
            if (httpResponse.statusCode == 200) {
              final bytes = <int>[];
              await for (final chunk in httpResponse) {
                bytes.addAll(chunk);
              }
              if (bytes.isNotEmpty) {
                AppLogger.success(
                  'Successfully loaded logo from profile URL (${bytes.length} bytes)',
                );
                return pw.MemoryImage(Uint8List.fromList(bytes));
              }
            }
            client.close();
          } catch (e) {
            AppLogger.error('Failed to load logo from URL', e);
            // Continue to fallback
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error fetching logo URL from profile', e);
      // Continue to fallback
    }

    // Fallback to loading from assets
    // Try loading from rootBundle first (for bundled assets)
    // Note: rootBundle.load() requires the path to match pubspec.yaml exactly
    final possibleAssetPaths = [
      'lib/assets/png/glanz.png', // Primary logo - exact path as in pubspec.yaml
      'lib/assets/png/glanzicon.png', // Fallback icon
    ];

    for (final path in possibleAssetPaths) {
      try {
        final byteData = await rootBundle.load(path);
        final imageBytes = byteData.buffer.asUint8List();
        if (imageBytes.isNotEmpty && imageBytes.length > 100) {
          AppLogger.success(
            'Successfully loaded logo from asset: $path (${imageBytes.length} bytes)',
          );
          return pw.MemoryImage(imageBytes);
        }
      } catch (e) {
        AppLogger.error('Failed to load logo from asset $path', e);
        continue;
      }
    }

    // Fallback: Try loading from file system using absolute path
    try {
      // Try multiple possible absolute paths
      final possiblePaths = [
        '/home/shahil/Desktop/Flutter_Supportta/glanz_rental/lib/assets/png/glanz.png',
        '${Directory.current.path}/lib/assets/png/glanz.png',
        'lib/assets/png/glanz.png',
      ];

      for (final filePath in possiblePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          if (imageBytes.isNotEmpty && imageBytes.length > 100) {
            AppLogger.success(
              'Successfully loaded logo from file system: $filePath (${imageBytes.length} bytes)',
            );
            return pw.MemoryImage(imageBytes);
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to load logo from file system', e);
    }

    AppLogger.warning('Could not load logo image from any source');
    return null;
  }

  /// Format currency with proper formatting (using Rs. instead of ₹ for PDF compatibility)
  static String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    // toStringAsFixed(2) always returns 2 decimal places, so parts[1] always exists
    final decimalPart = parts[1];
    // Add commas for thousands
    final regex = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    final formattedInteger = integerPart.replaceAllMapped(
      regex,
      (match) => '${match[1]},',
    );
    return 'Rs. $formattedInteger.$decimalPart';
  }

  /// Generate UPI payment string for QR code
  static String? _generateUpiPaymentString(
    String upiId,
    double amount,
    String merchantName,
    String invoiceNumber,
  ) {
    if (upiId.isEmpty) return null;

    // UPI payment URL format: upi://pay?pa=<UPI_ID>&pn=<MerchantName>&am=<Amount>&cu=INR&tn=<TransactionNote>
    final encodedMerchantName = Uri.encodeComponent(merchantName);
    final encodedNote = Uri.encodeComponent('Payment for Order $invoiceNumber');
    final amountString = amount.toStringAsFixed(2);

    return 'upi://pay?pa=$upiId&pn=$encodedMerchantName&am=$amountString&cu=INR&tn=$encodedNote';
  }

  /// Format date
  static String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  /// Get UPI ID from staff profile or current user profile
  static Future<String?> _getUpiIdForOrder(Order order) async {
    try {
      if (order.staff?.upiId != null && order.staff!.upiId!.isNotEmpty) {
        return order.staff!.upiId;
      }

      final user = SupabaseService.currentUser;
      if (user != null) {
        final response = await SupabaseService.client
            .from('profiles')
            .select('upi_id')
            .eq('id', user.id)
            .single();

        final upiId = response['upi_id']?.toString();
        if (upiId != null && upiId.isNotEmpty) {
          return upiId;
        }
      }
    } catch (e) {
      AppLogger.error('Error getting UPI ID', e);
    }
    return null;
  }

  /// Generate invoice PDF from order data - Matching website design
  static Future<Uint8List> generateInvoicePdf(Order order) async {
    final pdf = pw.Document();

    // Load logo - ensure it's loaded before building PDF
    AppLogger.debug('Loading logo image for PDF...');
    final logoImage = await _loadLogoImage();
    if (logoImage == null) {
      AppLogger.warning(
        'Logo image is null, PDF will be generated without logo',
      );
    } else {
      AppLogger.success('Logo image loaded successfully for PDF generation');
    }

    // Get UPI ID
    final upiId = await _getUpiIdForOrder(order);

    // Generate UPI payment string for QR code
    String? upiPaymentString;
    if (upiId != null && upiId.isNotEmpty) {
      // Get company name for merchant name in UPI
      String merchantName = 'GLANZ COSTUMES';
      try {
        final user = SupabaseService.currentUser;
        if (user != null) {
          final response = await SupabaseService.client
              .from('profiles')
              .select('company_name')
              .eq('id', user.id)
              .single();
          merchantName =
              response['company_name']?.toString() ??
              order.branch?.name ??
              order.staff?.fullName ??
              'GLANZ COSTUMES';
        }
      } catch (e) {
        merchantName =
            order.branch?.name ?? order.staff?.fullName ?? 'GLANZ COSTUMES';
      }
      upiPaymentString = _generateUpiPaymentString(
        upiId,
        order.totalAmount,
        merchantName,
        order.invoiceNumber,
      );
    }

    // Get company details and invoice settings from user profile
    String companyName = 'GLANZ COSTUMES';
    String companyAddress = '';
    String? phoneNumber;
    String? gstNumber;
    bool showInvoiceTerms = true; // Default to true
    bool showInvoiceQr = true; // Default to true

    try {
      final user = SupabaseService.currentUser;
      if (user != null) {
        try {
          // Prefer current column names (show_terms, show_qr_code)
          final response = await SupabaseService.client
              .from('profiles')
              .select(
                'company_name, company_address, phone, gst_number, show_terms, show_qr_code',
              )
              .eq('id', user.id)
              .single();

          companyName =
              response['company_name']?.toString() ??
              order.branch?.name ??
              'GLANZ COSTUMES';
          companyAddress =
              response['company_address']?.toString() ??
              order.branch?.address ??
              '';
          phoneNumber = response['phone']?.toString() ?? order.branch?.phone;
          gstNumber = response['gst_number']?.toString();

          // Get invoice settings from database (null means not set, default to true)
          final invoiceTermsValue = response['show_terms'] as bool?;
          final invoiceQrValue = response['show_qr_code'] as bool?;
          showInvoiceTerms = invoiceTermsValue ?? true;
          showInvoiceQr = invoiceQrValue ?? true;
        } on PostgrestException catch (e) {
          // If columns don't exist, try old names, else fall back to defaults
          if (e.code == 'PGRST204' ||
              e.message.contains('Could not find') ||
              e.message.contains('column')) {
            try {
              final response = await SupabaseService.client
                  .from('profiles')
                  .select(
                    'company_name, company_address, show_invoice_terms, show_invoice_qr',
                  )
                  .eq('id', user.id)
                  .single();

              companyName =
                  response['company_name']?.toString() ??
                  order.branch?.name ??
                  'GLANZ COSTUMES';
              companyAddress =
                  response['company_address']?.toString() ??
                  order.branch?.address ??
                  '';

              final invoiceTermsValue = response['show_invoice_terms'] as bool?;
              final invoiceQrValue = response['show_invoice_qr'] as bool?;
              showInvoiceTerms = invoiceTermsValue ?? true;
              showInvoiceQr = invoiceQrValue ?? true;
            } catch (e2) {
              AppLogger.warning(
                'Invoice setting columns missing, using defaults: $e2',
              );
              // Try to get company info without invoice columns
              try {
                final response = await SupabaseService.client
                    .from('profiles')
                    .select('company_name, company_address')
                    .eq('id', user.id)
                    .single();

                companyName =
                    response['company_name']?.toString() ??
                    order.branch?.name ??
                    'GLANZ COSTUMES';
                companyAddress =
                    response['company_address']?.toString() ??
                    order.branch?.address ??
                    '';
              } catch (e3) {
                AppLogger.error('Error getting company details', e3);
                companyName = order.branch?.name ?? 'GLANZ COSTUMES';
                companyAddress = order.branch?.address ?? '';
              }
              showInvoiceTerms = true;
              showInvoiceQr = true;
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Fallback to branch info if no user
        companyName = order.branch?.name ?? 'GLANZ COSTUMES';
        companyAddress = order.branch?.address ?? '';
      }
    } catch (e) {
      AppLogger.error('Error getting company details', e);
      // Fallback to branch info
      companyName = order.branch?.name ?? 'GLANZ COSTUMES';
      companyAddress = order.branch?.address ?? '';
    }

    // Get dates
    final bookingDate = order.createdAt;
    final startDate = order.startDatetime != null
        ? DateTime.parse(order.startDatetime!)
        : (DateTime.parse(order.startDate));
    final endDate = order.endDatetime != null
        ? DateTime.parse(order.endDatetime!)
        : (DateTime.parse(order.endDate));

    // Calculate rental days
    // Normalize to date only (midnight) to ensure accurate day calculation
    // For rental: same day = 1 day, next day = 1 day (overnight), etc.
    final startDateOnly = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
    final daysDifference = endDateOnly.difference(startDateOnly).inDays;
    final rentalDays = daysDifference < 1 ? 1 : daysDifference;

    // Parse address lines
    final addressLines = companyAddress
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    // Load all product images before building PDF
    AppLogger.debug('Loading product images for PDF...');
    final Map<String, pw.MemoryImage?> productImages = {};
    if (order.items != null && order.items!.isNotEmpty) {
      await Future.wait(
        order.items!.map((item) async {
          if (item.photoUrl.isNotEmpty && item.id != null) {
            final image = await _loadProductImage(item.photoUrl);
            productImages[item.id!] = image;
            if (image != null) {
              AppLogger.success(
                'Loaded product image for item: ${item.productName ?? item.id}',
              );
            }
          }
        }),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header - Matching website design
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.only(bottom: 16),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Logo and Company Info
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Logo
                        if (logoImage != null)
                          pw.Container(
                            width: 70,
                            height: 70,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          )
                        else
                          pw.Container(
                            width: 70,
                            height: 70,
                            margin: const pw.EdgeInsets.only(right: 12),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.grey200,
                              borderRadius: pw.BorderRadius.circular(8),
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                'LOGO',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        // Company Name and Address
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                companyName,
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (addressLines.isNotEmpty) ...[
                                pw.SizedBox(height: 6),
                                ...addressLines.map(
                                  (line) => pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                      bottom: 3,
                                    ),
                                    child: pw.Text(
                                      line,
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (phoneNumber != null &&
                                  phoneNumber.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Phone: $phoneNumber',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ],
                              if (gstNumber != null &&
                                  gstNumber.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'GSTIN: $gstNumber',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Right: Order Info
                  pw.Container(
                    width: 160,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'ORDER',
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          order.invoiceNumber,
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfColors.black,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          _formatDate(bookingDate),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bill To Section
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              padding: const pw.EdgeInsets.only(bottom: 14),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'BILL TO',
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    order.customer?.name ?? 'N/A',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  if (order.customer?.phone != null) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      order.customer!.phone,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                  if (order.customer?.address != null) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      order.customer!.address!,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Rental Period
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 14),
              padding: const pw.EdgeInsets.only(bottom: 14),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 1),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RENTAL PERIOD',
                    style: pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_formatDate(startDate)} to ${_formatDate(endDate)} ($rentalDays ${rentalDays == 1 ? 'day' : 'days'})',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Items Table
            pw.Table(
              border: pw.TableBorder(
                top: const pw.BorderSide(color: PdfColors.grey300, width: 1),
                bottom: const pw.BorderSide(color: PdfColors.grey300, width: 1),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8), // Sl No
                1: const pw.FlexColumnWidth(1), // Image column
                2: const pw.FlexColumnWidth(3), // Item name
                3: const pw.FlexColumnWidth(1), // Quantity
                4: const pw.FlexColumnWidth(1.5), // Price/Day
                5: const pw.FlexColumnWidth(1.5), // Total
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF9FAFB),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Sl. No.',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Photo',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Product Name',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Price',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                // Item Rows
                ...(order.items ?? []).asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final productImage = item.id != null
                      ? productImages[item.id!]
                      : null;

                  final isEven = index % 2 == 0;
                  return pw.TableRow(
                    decoration: isEven
                        ? null
                        : const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFFAFBFC),
                          ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          (index + 1).toString(),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: productImage != null
                            ? pw.Container(
                                width: 50,
                                height: 50,
                                child: pw.Image(
                                  productImage,
                                  fit: pw.BoxFit.cover,
                                ),
                              )
                            : pw.Container(
                                width: 50,
                                height: 50,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey200,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                                child: pw.Center(
                                  child: pw.Text(
                                    'No Image',
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      color: PdfColors.black,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          item.productName ?? 'N/A',
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          item.quantity.toString(),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _formatCurrency(item.pricePerDay),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.black,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _formatCurrency(item.lineTotal),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 12),

            // Summary Section - Matching website design
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: pw.SizedBox()),
                  pw.Container(
                    width: 240,
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        // Total Amount
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                color: PdfColors.grey300,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Total Amount',
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  color: PdfColors.black,
                                  fontWeight: pw.FontWeight.normal,
                                ),
                              ),
                              pw.Text(
                                _formatCurrency(order.subtotal ?? 0),
                                style: pw.TextStyle(
                                  fontSize: 6,
                                  color: PdfColors.black,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // GST
                        if (order.gstAmount != null &&
                            order.gstAmount! > 0) ...[
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 3),
                            margin: const pw.EdgeInsets.only(bottom: 3),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                  color: PdfColors.grey300,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'GST (${((order.gstAmount! / (order.subtotal ?? 1)) * 100).toStringAsFixed(2)}%)',
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColors.black,
                                    fontWeight: pw.FontWeight.normal,
                                  ),
                                ),
                                pw.Text(
                                  _formatCurrency(order.gstAmount!),
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColors.black,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Final Amount
                        pw.Container(
                          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                          margin: const pw.EdgeInsets.only(top: 4),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(
                                color: PdfColors.black,
                                width: 1,
                              ),
                            ),
                          ),
                          child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Final Amount',
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  color: PdfColor.fromInt(
                                    0xFFDC2626,
                                  ), // Red color
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                _formatCurrency(
                                  (order.subtotal ?? 0) +
                                      (order.gstAmount ?? 0),
                                ),
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColor.fromInt(
                                    0xFFDC2626,
                                  ), // Red color
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Security Deposit (separate, in green)
                        if (order.securityDepositAmount != null &&
                            order.securityDepositAmount! > 0) ...[
                          pw.Container(
                            padding: const pw.EdgeInsets.only(
                              top: 8,
                              bottom: 3,
                            ),
                            margin: const pw.EdgeInsets.only(top: 8),
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                top: pw.BorderSide(
                                  color: PdfColors.grey300,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'Security Deposit',
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColor.fromInt(
                                      0xFF16A34A,
                                    ), // Green color
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  _formatCurrency(order.securityDepositAmount!),
                                  style: pw.TextStyle(
                                    fontSize: 6,
                                    color: PdfColor.fromInt(
                                      0xFF16A34A,
                                    ), // Green color
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 32),

            // Terms & Conditions and Scan & Pay Section (only show if enabled in settings)
            if (showInvoiceTerms || showInvoiceQr) ...[
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Terms & Conditions (only if enabled)
                  if (showInvoiceTerms)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TERMS & CONDITIONS',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            width: double.infinity,
                            height: 1,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '- ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  'All items must be returned in good condition',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '- ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  'Late returns may incur additional charges as per policy',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '- ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  'Damage or loss of items will be charged at replacement cost',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '- ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  'Rental period must be strictly adhered to',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '- ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  'Please contact us for any queries or concerns',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '- ',
                                style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  'This invoice is valid for accounting and tax purposes',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Spacing between terms and QR code
                  if (showInvoiceTerms && showInvoiceQr) pw.SizedBox(width: 24),
                  // Right: Scan & Pay (only if enabled)
                  if (showInvoiceQr &&
                      upiPaymentString != null &&
                      upiId != null &&
                      upiId.isNotEmpty)
                    pw.Container(
                      width: 180,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'SCAN & PAY',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                          pw.SizedBox(height: 8),
                          pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: upiPaymentString,
                            width: 120,
                            height: 120,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'UPI: $upiId | Amount:',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                          pw.Text(
                            _formatCurrency(order.totalAmount),
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.black,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ];
        },
      ),
    );

    return await pdf.save();
  }

  // Keep existing methods unchanged...
  static Future<void> viewInvoice(Order order) async {
    try {
      final pdfBytes = await generateInvoicePdf(order);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      throw Exception('Failed to view invoice: $e');
    }
  }

  static Future<void> shareOnWhatsApp(Order order) async {
    try {
      final pdfBytes = await generateInvoicePdf(order);
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Invoice_${order.invoiceNumber}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      final xFile = XFile(file.path, mimeType: 'application/pdf');
      final customerName = order.customer?.name ?? 'Customer';
      final customerPhone = order.customer?.phone ?? '';
      final message =
          'Hello $customerName,\n\n'
          'Please find your invoice attached:\n'
          'Invoice #: ${order.invoiceNumber}\n'
          'Amount: ${_formatCurrency(order.totalAmount)}\n'
          'Date: ${_formatDate(order.createdAt)}\n\n'
          'Customer: $customerName ($customerPhone)\n\n'
          'Thank you for your business!';
      await Share.shareXFiles(
        [xFile],
        text: message,
        subject: 'Invoice ${order.invoiceNumber}',
      );
    } catch (e) {
      throw Exception('Failed to share invoice PDF: ${e.toString()}');
    }
  }

  static Future<String> downloadInvoice(Order order) async {
    try {
      final pdfBytes = await generateInvoicePdf(order);
      final fileName = 'Invoice_${order.invoiceNumber}.pdf';

      if (Platform.isAndroid) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(pdfBytes);
        final xFile = XFile(tempFile.path, mimeType: 'application/pdf');
        await Share.shareXFiles([xFile], subject: fileName);
        return 'Downloads/$fileName';
      } else if (Platform.isIOS) {
        final downloadDir = await getApplicationDocumentsDirectory();
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        return file.path;
      } else {
        final downloadDir = await getApplicationDocumentsDirectory();
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        return file.path;
      }
    } catch (e) {
      throw Exception('Failed to download invoice: ${e.toString()}');
    }
  }

  static Future<void> printInvoice(Order order) async {
    try {
      final pdfBytes = await generateInvoicePdf(order);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      throw Exception('Failed to print invoice: ${e.toString()}');
    }
  }
}
