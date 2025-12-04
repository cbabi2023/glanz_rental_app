import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../core/supabase_client.dart';

/// Invoice Service - Updated to match website design
///
/// Handles invoice PDF generation, viewing, sharing, and downloading
class InvoiceService {
  /// Load logo image from assets
  static Future<pw.MemoryImage?> _loadLogoImage() async {
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
          print(
            '✅ Successfully loaded logo from asset: $path (${imageBytes.length} bytes)',
          );
          return pw.MemoryImage(imageBytes);
        }
      } catch (e) {
        print('❌ Failed to load logo from asset $path: $e');
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
            print(
              '✅ Successfully loaded logo from file system: $filePath (${imageBytes.length} bytes)',
            );
            return pw.MemoryImage(imageBytes);
          }
        }
      }
    } catch (e) {
      print('❌ Failed to load logo from file system: $e');
    }

    print('⚠️ Warning: Could not load logo image from any source');
    return null;
  }

  /// Format currency with proper formatting
  static String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1] ?? '00';
    // Add commas for thousands
    final regex = RegExp(r'(\d)(?=(\d{3})+(?!\d))');
    final formattedInteger = integerPart.replaceAllMapped(
      regex,
      (match) => '${match[1]},',
    );
    return '₹$formattedInteger.$decimalPart';
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
      print('Error getting UPI ID: $e');
    }
    return null;
  }

  /// Generate invoice PDF from order data - Matching website design
  static Future<Uint8List> generateInvoicePdf(Order order) async {
    final pdf = pw.Document();

    // Load logo - ensure it's loaded before building PDF
    print('🔄 Loading logo image for PDF...');
    final logoImage = await _loadLogoImage();
    if (logoImage == null) {
      print(
        '⚠️ Warning: Logo image is null, PDF will be generated without logo',
      );
    } else {
      print('✅ Logo image loaded successfully for PDF generation');
    }

    // Get UPI ID
    final upiId = await _getUpiIdForOrder(order);

    // Get branch info
    final branchName = order.branch?.name ?? 'GLANZ COSTUMES';
    final branchAddress = order.branch?.address ?? '';
    final branchPhone = order.branch?.phone ?? '';
    final branchGstin = order.staff?.gstNumber ?? '';

    // Get dates
    final bookingDate = order.createdAt;
    final startDate = order.startDatetime != null
        ? DateTime.parse(order.startDatetime!)
        : (DateTime.parse(order.startDate));
    final endDate = order.endDatetime != null
        ? DateTime.parse(order.endDatetime!)
        : (DateTime.parse(order.endDate));

    // Calculate rental days
    final rentalDays = endDate.difference(startDate).inDays + 1;

    // Parse address lines
    final addressLines = branchAddress
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final phoneNumbers = branchPhone.split(',').map((p) => p.trim()).toList();

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
                                  color: PdfColors.grey600,
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
                                branchName,
                                style: pw.TextStyle(
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey900,
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
                                        fontSize: 8.5,
                                        color: PdfColors.grey600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (phoneNumbers.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  phoneNumbers.join(', '),
                                  style: pw.TextStyle(
                                    fontSize: 8.5,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                              ],
                              if (branchGstin.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'GSTIN: $branchGstin',
                                  style: pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey600,
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
                          'ORDERS',
                          style: pw.TextStyle(
                            fontSize: 26,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          order.invoiceNumber,
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          _formatDate(bookingDate),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.grey500,
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
                      color: PdfColors.grey400,
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
                      color: PdfColors.grey900,
                    ),
                  ),
                  if (order.customer?.phone != null) ...[
                    pw.SizedBox(height: 5),
                    pw.Text(
                      order.customer!.phone,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                  if (order.customer?.address != null) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      order.customer!.address!,
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColors.grey600,
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
                      color: PdfColors.grey400,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_formatDate(startDate)} to ${_formatDate(endDate)} ($rentalDays ${rentalDays == 1 ? 'day' : 'days'})',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey900,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Products Table
            pw.Text(
              'Order Items',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
            pw.SizedBox(height: 12),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
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
                          color: PdfColors.grey900,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Price/Day',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Days',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
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
                          color: PdfColors.grey900,
                        ),
                      ),
                    ),
                  ],
                ),
                // Item Rows
                ...(order.items ?? []).map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          item.productName ?? 'N/A',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          item.quantity.toString(),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _formatCurrency(item.pricePerDay),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          item.days.toString(),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          _formatCurrency(item.lineTotal),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 24),

            // Totals Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: pw.SizedBox()),
                pw.Container(
                  width: 280,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Subtotal
                      if (order.subtotal != null) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Subtotal',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              _formatCurrency(order.subtotal!),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey900,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                      ],
                      // GST
                      if (order.gstAmount != null && order.gstAmount! > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'GST',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              _formatCurrency(order.gstAmount!),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey900,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                      ],
                      // Late Fee
                      if (order.lateFee != null && order.lateFee! > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'Late Fee',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.Text(
                              _formatCurrency(order.lateFee!),
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey900,
                                fontWeight: pw.FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                      ],
                      // Divider
                      pw.Divider(color: PdfColors.grey400, height: 1),
                      pw.SizedBox(height: 8),
                      // Total
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total Amount',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                          pw.Text(
                            _formatCurrency(order.totalAmount),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 32),

            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Payment Information',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  if (upiId != null && upiId.isNotEmpty) ...[
                    pw.Text(
                      'UPI ID: $upiId',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Text(
                    'Thank you for your business!',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
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
