import 'package:flutter/services.dart';





class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    

    final limitedDigits = digitsOnly.length > 11 
        ? digitsOnly.substring(0, 11) 
        : digitsOnly;
    

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
    


    final oldTextBeforeCursor = oldValue.text.substring(0, oldValue.selection.start);
    final oldDigitsBeforeCursor = oldTextBeforeCursor.replaceAll(RegExp(r'[^\d]'), '').length;
    

    final isAdding = limitedDigits.length > oldDigitsBeforeCursor;
    final isDeleting = limitedDigits.length < oldDigitsBeforeCursor;
    

    int newCursorPosition = formatted.length;
    
    if (isAdding) {

      newCursorPosition = formatted.length;
    } else if (isDeleting) {


      if (limitedDigits.isEmpty) {
        newCursorPosition = 0;
      } else {
        int digitCount = 0;
        for (int i = 0; i < formatted.length; i++) {
          if (formatted[i] != '-') {
            digitCount++;
            if (digitCount == limitedDigits.length) {

              newCursorPosition = i + 1;
              break;
            }
          }
        }

        if (newCursorPosition == formatted.length && limitedDigits.isNotEmpty) {
          newCursorPosition = formatted.length;
        }
      }
    }

    

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

