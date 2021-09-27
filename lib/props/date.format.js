function dateFormat(fecha) {
	const aux = fecha.split('-');
	return `${aux[2]}-${aux[1]}-${aux[0]}`;
}
// entrada -> salida "18-01-2025 | 00:00"
function dateFormatPG(fecha) {
	var aux = fecha.split('+');
	return dateFormat(aux[0]) + ' | ' + aux[1];
}

function dateNow(){
	var today = new Date();
	return today.getFullYear()+'-'+(today.getMonth()+1)+'-'+today.getDate();
}
// devuelve fecha 2021
function formateToInputs(fecha){
	debugger;
	var local = new Date(fecha);
	return local.toJSON().slice(0, 10);
}

Date.prototype.toDateInputValue = (function(fecha) {
	var local = new Date(fecha);
	return local.toJSON().slice(0, 10);
});