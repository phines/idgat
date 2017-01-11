function selector(element,
		  index) {
	return this[index];
}

var array = [
	1,
	2,
	3,
	4,
	5,
	6,
	7,
	8,
	9
];

var flag = [
	0,
	1,
	1,
	0,
	1,
	0,
	1,
	1,
	1
];

// See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/filter:
array.filter(selector, // callback
	     flag      // thisArg
	    );

////////////////////////////////////////////////////////////////////////////////////////////////////////////
