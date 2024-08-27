function processSpreadsheetData() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var lastColumn = sheet.getLastColumn();
  var lastRow = sheet.getLastRow();
  var headers = sheet.getRange(1, 1, 1, lastColumn).getValues()[0];

  // Iterate over columns to convert "Name" column values to proper case, format "Phone" numbers, and handle "x" values
  for (var l = 0; l < headers.length; l++) {
    var header = headers[l].toLowerCase();
    if (header.indexOf("name") !== -1) {
      var nameColumnRange = sheet.getRange(2, l + 1, lastRow - 1, 1); // Exclude header row
      var nameColumnValues = nameColumnRange.getValues();
      
      for (var m = 0; m < nameColumnValues.length; m++) {
        if (nameColumnValues[m][0] !== "") { // Exclude empty cells
          nameColumnValues[m][0] = toProperCase(nameColumnValues[m][0]);
        }
      }
      
      nameColumnRange.setValues(nameColumnValues);
    } 
    else if (header.indexOf("phone") !== -1) {
      var phoneColumnRange = sheet.getRange(2, l + 1, lastRow - 1, 1); // Exclude header row
      var phoneColumnValues = phoneColumnRange.getValues();
      
      for (var n = 0; n < phoneColumnValues.length; n++) {
        if (phoneColumnValues[n][0] !== "" && phoneColumnValues[n][0].toString().replace(/\D/g,'').length === 10) { // Exclude empty cells and only format if 10 digits
          phoneColumnValues[n][0] = formatPhoneNumber(phoneColumnValues[n][0]);
        }
      }
      
      phoneColumnRange.setValues(phoneColumnValues);
    }
  }

  // Populate "State" column based on column headers
  populateStateColumn(sheet, headers, lastRow);

  // Check and create "tag_list" column
  createTagListColumn(sheet, headers, lastColumn);

  // Handle cells with value "x"
  handleXValues(sheet, headers, lastColumn, lastRow);
}

function populateStateColumn(sheet, headers, lastRow) {
  for (var i = 0; i < headers.length; i++) {
    var header = headers[i].trim();
    var headerLowerCase = header.toLowerCase();
    if (headerLowerCase.indexOf("state ") !== -1 && header.length === 8) {
      var stateCode = headerLowerCase.substring(6).toUpperCase(); // Extract the state code from the header
      var columnIndex = i + 1;
      
      // Populate all values in the column with the state code
      var range = sheet.getRange(2, columnIndex, lastRow - 1, 1); // Exclude header row
      var stateValues = new Array(lastRow - 1).fill(stateCode);
      range.setValues(stateValues.map(function(value) { return [value]; }));
      
      break; // If one such column is found, no need to check further
    }
  }
}

function createTagListColumn(sheet, headers, lastColumn) {
  var tagListColumnIndex = -1;
  // Check if "tag_list" column exists
  for (var k = 0; k < headers.length; k++) {
    if (headers[k].toLowerCase() === "tag_list") {
      tagListColumnIndex = k + 1;
      break;
    }
  }

  // If "tag_list" column doesn't exist, create it
  if (tagListColumnIndex === -1) {
    tagListColumnIndex = lastColumn + 1;
    sheet.getRange(1, tagListColumnIndex).setValue("tag_list");
  }
}

function handleXValues(sheet, headers, lastColumn, lastRow) {
  var tagListColumnIndex = -1;
  for (var k = 0; k < headers.length; k++) {
    if (headers[k].toLowerCase() === "tag_list") {
      tagListColumnIndex = k + 1;
      break;
    }
  }

  var xColumns = [];
  for (var c = 0; c < lastColumn; c++) {
    var values = sheet.getRange(2, c + 1, lastRow - 1, 1).getValues().flat();
    if (values.includes("x")) {
      xColumns.push(c + 1);
    }
  }

  var tagListValues = [];
  for (var r = 2; r <= lastRow; r++) {
    var rowValues = [];
    for (var x = 0; x < xColumns.length; x++) {
      var cellValue = sheet.getRange(r, xColumns[x]).getValue();
      if (cellValue === "x") {
        cellValue = headers[xColumns[x] - 1]; // Adjusted for 0-based index
      }
      if (cellValue !== "") {
        rowValues.push(cellValue);
      }
    }
    var tagListValue = rowValues.join(",");
    tagListValues.push([tagListValue]);
  }

  var tagListColumn = sheet.getRange(2, tagListColumnIndex, tagListValues.length, 1);
  tagListColumn.setValues(tagListValues);

  // Remove "x" columns
  xColumns.reverse().forEach(function(c) {
    sheet.deleteColumn(c);
  });
}

function toProperCase(str) {
  return str.replace(/\w\S*/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
}

function formatPhoneNumber(phone) {
  // Remove non-digit characters from the phone number
  phone = phone.toString().replace(/\D/g, '');
  
  // Format the phone number as xxx-xxx-xxxx if it's exactly 10 digits long
  if (phone.length === 10) {
    return phone.replace(/(\d{3})(\d{3})(\d{4})/, '$1-$2-$3');
  } else {
    // Return the original value if it's not a 10-digit number
    return phone;
  }
}
