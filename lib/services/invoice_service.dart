import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../core/config.dart';
import '../core/supabase_client.dart';

/// Invoice Service
///
/// Handles invoice PDF generation, viewing, sharing, and downloading
class InvoiceService {
  /// Get invoice URL from website (if available)
  /// Replace this URL with your actual website invoice endpoint
  static String getInvoiceUrl(String orderId, String invoiceNumber) {
    // TODO: Replace with your actual website invoice URL
    // Example: 'https://yourwebsite.com/invoice/$invoiceNumber'
    // or 'https://yourwebsite.com/api/invoices/$orderId'
    return '${AppConfig.supabaseUrl.replaceAll('.supabase.co', '')}/invoice/$invoiceNumber';
  }

  /// Get UPI ID from staff profile or current user profile
  static Future<String?> _getUpiIdForOrder(Order order) async {
    try {
      // First try to get from staff profile in order
      if (order.staff?.upiId != null && order.staff!.upiId!.isNotEmpty) {
        return order.staff!.upiId;
      }
      
      // If not available, try to get from current user profile
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
      // If error, return null - QR code won't be shown
      print('Error getting UPI ID: $e');
    }
    return null;
  }

  /// Generate invoice PDF from order data
  static Future<Uint8List> generateInvoicePdf(Order order) async {
    final pdf = pw.Document();

    // Get UPI ID before building PDF
    final upiId = await _getUpiIdForOrder(order);
    String? upiPaymentString;
    
    if (upiId != null && upiId.isNotEmpty) {
      // Generate UPI payment string
      final businessName = order.branch?.name ?? order.staff?.fullName ?? 'Glanz Rental';
      final amount = order.totalAmount.toStringAsFixed(2);
      upiPaymentString = 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(businessName)}&am=$amount&cu=INR&tn=${Uri.encodeComponent('Payment for Invoice ${order.invoiceNumber}')}';
    }

    // Use default fonts - pdf package provides built-in fonts

    // Helper to format currency - use "Rs." instead of rupee symbol for PDF compatibility
    String formatCurrency(double amount) {
      return 'Rs. ${amount.toStringAsFixed(2)}';
    }

    // Helper to format date
    String formatDate(String dateStr) {
      try {
        final date = DateTime.parse(dateStr);
        return '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        return dateStr;
      }
    }

    // Helper to format datetime
    String formatDateTime(String? dateTimeStr) {
      if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
      try {
        final date = DateTime.parse(dateTimeStr);
        return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        return dateTimeStr;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 32,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Invoice #${order.invoiceNumber}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'GLANZ RENTAL',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Rental Services',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Order Information
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Customer Information
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Customer Details',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        order.customer?.name ?? 'N/A',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      if (order.customer?.phone != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Phone: ${order.customer!.phone}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                      if (order.customer?.email != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Email: ${order.customer!.email}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                      if (order.customer?.address != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Address: ${order.customer!.address}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 40),
                // Order Information
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Order Information',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Date: ${formatDate(order.createdAt.toIso8601String())}',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Status: ${order.status.value.toUpperCase()}',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      if (order.branch?.name != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Branch: ${order.branch!.name}',
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Rental Period
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rental Start',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        formatDateTime(order.startDatetime ?? order.startDate),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 1,
                    height: 40,
                    color: PdfColors.grey300,
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rental End',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        formatDateTime(order.endDatetime ?? order.endDate),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Items Table
            pw.Text(
              'Order Items',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Qty',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Price/Day',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Days',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
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
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item.productName ?? 'N/A',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item.quantity.toString(),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          formatCurrency(item.pricePerDay),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          item.days.toString(),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          formatCurrency(item.lineTotal),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 30),

            // Pricing Summary
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 250,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    if (order.subtotal != null) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Subtotal',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            formatCurrency(order.subtotal!),
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    if (order.gstAmount != null && order.gstAmount! > 0) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'GST',
                            style: pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            formatCurrency(order.gstAmount!),
                            style: pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    if (order.lateFee != null && order.lateFee! > 0) ...[
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Late Fee',
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.red700,
                            ),
                          ),
                          pw.Text(
                            formatCurrency(order.lateFee!),
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.red700,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                    ],
                    pw.Divider(color: PdfColors.grey400),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Amount',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(order.totalAmount),
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 40),

            // Payment QR Code Section - show if UPI ID is available
            if (upiPaymentString != null && upiId != null && upiId.isNotEmpty) ...[
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Scan to Pay',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: upiPaymentString,
                      width: 150,
                      height: 150,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'UPI ID: $upiId',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Amount: ${formatCurrency(order.totalAmount)}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
            ],
            
            // Footer
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'For any queries, please contact us.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  /// View invoice PDF
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

  /// Share invoice PDF on WhatsApp
  /// Shares the PDF file - user selects WhatsApp from share dialog to send
  static Future<void> shareOnWhatsApp(Order order) async {
    try {
      // Generate PDF first
      final pdfBytes = await generateInvoicePdf(order);
      
      // Save PDF to temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Invoice_${order.invoiceNumber}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      // Create XFile from the saved file
      final xFile = XFile(file.path, mimeType: 'application/pdf');
      
      // Create message text with customer info
      final customerName = order.customer?.name ?? 'Customer';
      final customerPhone = order.customer?.phone ?? '';
      final message = 'Hello $customerName,\n\n'
          'Please find your invoice attached:\n'
          'Invoice #: ${order.invoiceNumber}\n'
          'Amount: Rs. ${order.totalAmount.toStringAsFixed(2)}\n'
          'Date: ${DateFormat('dd MMM yyyy').format(order.createdAt)}\n\n'
          'Customer: $customerName ($customerPhone)\n\n'
          'Thank you for your business!';

      // Share the PDF file with message
      // User needs to select WhatsApp from share dialog and choose the customer contact
      await Share.shareXFiles(
        [xFile],
        text: message,
        subject: 'Invoice ${order.invoiceNumber}',
      );
    } catch (e) {
      throw Exception('Failed to share invoice PDF: ${e.toString()}');
    }
  }

  /// Download invoice PDF
  /// Uses share_plus to save file - ensures it's visible in file manager
  /// User can select "Save to Downloads" from the dialog
  static Future<String> downloadInvoice(Order order) async {
    try {
      final pdfBytes = await generateInvoicePdf(order);
      final fileName = 'Invoice_${order.invoiceNumber}.pdf';
      
      if (Platform.isAndroid) {
        // Save PDF to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(pdfBytes);
        final xFile = XFile(tempFile.path, mimeType: 'application/pdf');
        
        // Use share_plus to open system save dialog
        // This is the most reliable way to save files visible in file manager on all Android versions
        // User can select "Save to Downloads" or any other location
        await Share.shareXFiles(
          [xFile],
          subject: fileName,
        );
        
        // Return path for user feedback
        return 'Downloads/$fileName';
      } else if (Platform.isIOS) {
        // For iOS, use app documents directory
        final downloadDir = await getApplicationDocumentsDirectory();
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        return file.path;
      } else {
        // For other platforms, use app documents directory
        final downloadDir = await getApplicationDocumentsDirectory();
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        return file.path;
      }
    } catch (e) {
      throw Exception('Failed to download invoice: ${e.toString()}');
    }
  }
  
}

