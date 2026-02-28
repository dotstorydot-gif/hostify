import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfReceiptService {
  /// Generate PDF receipt for a booking
  static Future<File> generateBookingReceipt({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> property,
    required Map<String, dynamic> guest,
  }) async {
    final pdf = pw.Document();

    // Load logo (optional)
    // final logo = await rootBundle.load('assets/images/hostifylogo.png');
    // final logoImage = pw.MemoryImage(logo.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 30),

              // Booking Details
              _buildSection('Booking Information', [
                _buildRow('Booking ID', booking['id'].toString().substring(0, 8).toUpperCase()),
                _buildRow('Status', booking['status'].toString().toUpperCase()),
                _buildRow('Booking Date', _formatDate(booking['created_at'])),
              ]),
              pw.SizedBox(height: 20),

              // Property Details
              _buildSection('Property Details', [
                _buildRow('Property', property['name']),
                _buildRow('Location', property['location']),
                _buildRow('Check-in', _formatDate(booking['check_in'])),
                _buildRow('Check-out', _formatDate(booking['check_out'])),
                _buildRow('Nights', booking['nights'].toString()),
                _buildRow('Guests', booking['guests']?.toString() ?? '1'),
              ]),
              pw.SizedBox(height: 20),

              // Guest Details
              _buildSection('Guest Information', [
                _buildRow('Name', guest['full_name'] ?? 'N/A'),
                _buildRow('Email', guest['email'] ?? 'N/A'),
                _buildRow('Phone', guest['phone'] ?? 'N/A'),
              ]),
              pw.SizedBox(height: 20),

              // Price Breakdown
              _buildSection('Price Breakdown', [
                _buildRow(
                  '${property['price_per_night']} x ${booking['nights']} nights',
                  '\$${(property['price_per_night'] * booking['nights']).toStringAsFixed(2)}',
                ),
                pw.Divider(),
                _buildRow(
                  'Total',
                  '\$${booking['total_price'].toStringAsFixed(2)}',
                  bold: true,
                ),
              ]),
              pw.SizedBox(height: 30),

              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );

    // Save to file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/booking_receipt_${booking['id']}.pdf');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }

  static pw.Widget _buildHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFD700'),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'BOOKING RECEIPT',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '.Hostify',
            style: const pw.TextStyle(
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#2D3748'),
            ),
          ),
          pw.SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Thank you for booking with .Hostify!',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'For any questions or concerns, please contact us at:',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Email: info@dot-story.com',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Phone: +201006119667',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  static String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    final DateTime dt = date is String ? DateTime.parse(date) : date;
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  /// Share or download PDF
  static Future<void> sharePdf(File pdfFile) async {
    await Printing.sharePdf(
      bytes: await pdfFile.readAsBytes(),
      filename: pdfFile.path.split('/').last,
    );
  }

  /// Print PDF
  static Future<void> printPdf(File pdfFile) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => await pdfFile.readAsBytes(),
    );
  }
}
