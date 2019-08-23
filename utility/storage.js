//Sort the table
function sortTable(n) {
  var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
  table = document.getElementById("inventoryTable");
  switching = true;
  // Set the sorting direction to ascending:
  dir = "asc";
  /* Make a loop that will continue until
  no switching has been done: */
  while (switching) {
    // Start by saying: no switching is done:
    switching = false;
    rows = table.rows;
    /* Loop through all table rows (except the
    first, which contains table headers): */
    for (i = 1; i < (rows.length - 1); i++) {
      // Start by saying there should be no switching:
      shouldSwitch = false;
      /* Get the two elements you want to compare,
      one from current row and one from the next: */
      x = rows[i].getElementsByTagName("TD")[n];
      y = rows[i + 1].getElementsByTagName("TD")[n];
      /* Check if the two rows should switch place,
      based on the direction, asc or desc: */
      if (dir == "asc") {
        if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
          // If so, mark as a switch and break the loop:
          shouldSwitch = true;
          break;
        }
      } else if (dir == "desc") {
        if (x.innerHTML.toLowerCase() < y.innerHTML.toLowerCase()) {
          // If so, mark as a switch and break the loop:
          shouldSwitch = true;
          break;
        }
      }
    }
    if (shouldSwitch) {
      /* If a switch has been marked, make the switch
      and mark that a switch has been done: */
      rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
      switching = true;
      // Each time a switch is done, increase this count by 1:
      switchcount ++;
    } else {
      /* If no switching has been done AND the direction is "asc",
      set the direction to "desc" and run the while loop again. */
      if (switchcount == 0 && dir == "asc") {
        dir = "desc";
        switching = true;
      }
    }
  }
}

// convert fake dates
function getTime(time) {
  if(typeof time !== 'undefined') {
    return (new Date(time.toString())).getTime();
  }
}

// sort by date descending
function byTime(a, b) {
  const later = getTime(a.Timestamp) > getTime(b.Timestamp);

  switch (later) {
    case true:
      return -1;
      break;

    case false:
      return 1;
      break;

    default:
      return 0;
  }
}

function byField(field) {
  return function(a, b) {
    const numeric = typeof a[field] === 'number' && typeof b[field] === 'number';
    const aStr = a[field].toString();
    const bStr = b[field].toString();

    return aStr.localeCompare(bStr, 'kn', {numeric: numeric});
  }
};

module.exports.getLastNRows = function(azure, tableService, columns, n, sort, callback) {
  const query = new azure.TableQuery()
    .select(columns)
    .top(n);

    tableService.queryEntities(process.env.TABLE_NAME, query, null, function(error, result, response) {
      if (error) return callback(error);

      // each prop in the results comes back with a nested prop of `_`,
      // so this flattens the props and filters out metadata prop also
      const rows = result.entries.map(e => {
        return Object.keys(e)
          .filter(k => k !== '.metadata')
          .reduce((a, b) => {
            const flatProp = { [b]: e[b]._ };
            return Object.assign(a, flatProp);
          }, {});
      });

    const sortStrategy = (sort === 'Timestamp') ? byTime : byField(sort);
    const sorted = rows.slice().sort(sortStrategy);

    return callback(null, sorted);
  });
};
