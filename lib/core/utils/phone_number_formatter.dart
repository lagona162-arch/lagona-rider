import 'package:flutter/services.dart';

/// Custom TextInputFormatter for Philippine phone numbers
/// Formats input as: 0912-345-6789 (with dashes)
/// Stores value as: 09123456789 (without dashes)
/// Maximum 11 digits
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits from the new value
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 11 digits
    final limitedDigits = digitsOnly.length > 11 
        ? digitsOnly.substring(0, 11) 
        : digitsOnly;
    
    // Format as 0912-345-6789
    String formatted = '';
    if (limitedDigits.isEmpty) {
      formatted = '';
    } else if (limitedDigits.length <= 4) {
      formatted = limitedDigits;
    } else if (limitedDigits.length <= 7) {
      formatted = '${limitedDigits.substring(0, 4)}-${limitedDigits.substring(4)}';
    } else {
      formatted = '${limitedDigits.substring(0, 4)}-${limitedDigits.substring(4, 7)}-${limitedDigits.substring(7)}';
    }
    
    // Calculate cursor position
    // Get the number of digits that were before the cursor in the old value
    final oldTextBeforeCursor = oldValue.text.substring(0, oldValue.selection.start);
    final oldDigitsBeforeCursor = oldTextBeforeCursor.replaceAll(RegExp(r'[^\d]'), '').length;
    
    // Determine if we're adding or deleting
    final isAdding = limitedDigits.length > oldDigitsBeforeCursor;
    final isDeleting = limitedDigits.length < oldDigitsBeforeCursor;
    
    // Initialize cursor position
    int newCursorPosition = formatted.length;
    
    if (isAdding) {
      // When adding digits, place cursor at the end
      newCursorPosition = formatted.length;
    } else if (isDeleting) {
      // When deleting, try to maintain relative position
      // Find the position in formatted string that corresponds to the new digit count
      if (limitedDigits.isEmpty) {
        newCursorPosition = 0;
      } else {
        int digitCount = 0;
        for (int i = 0; i < formatted.length; i++) {
          if (formatted[i] != '-') {
            digitCount++;
            if (digitCount == limitedDigits.length) {
              // Place cursor right after the last digit
              newCursorPosition = i + 1;
              break;
            }
          }
        }
        // Fallback: if we didn't find a position, place at end
        if (newCursorPosition == formatted.length && limitedDigits.isNotEmpty) {
          newCursorPosition = formatted.length;
        }
      }
    }
    // else: same number of digits - keep cursor at end (already initialized)
    
    // Ensure cursor position is within bounds
    if (newCursorPosition < 0) {
      newCursorPosition = 0;
    }
    if (newCursorPosition > formatted.length) {
      newCursorPosition = formatted.length;
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}

