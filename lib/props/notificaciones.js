function hecho(msj="Hecho", detalle="Guardado con Éxito!"){
    Swal.fire(
        msj,
        detalle,
        'success'
      )
}

function rehecho(msj="Hecho", detalle="Guardado con Éxito!"){
  Swal.fire(
      msj,
      detalle,
      'success'
    ).then((result) => {
      $('.modal-backdrop ').remove();
      if(result.value) linkTo();
    });
}

function error(msj='Error!', detalle="Algo salio mal"){
    Swal.fire(
        msj,
        detalle,
        'error'
      )
}

function falla() {
  alert('Falla');
}

function msj(msj){
  alert(msj);
}

function notificar(msj="Hecho", detalle="Guardado con Éxito!", tipo="success"){
  Swal.fire(msj,detalle,tipo);
}

function bolita(texto, color, detalle = null)
{
    return `<span data-toggle='tooltip' title='${detalle}' class='badge bg-${color} estado'>${texto}</span>`;
}

var s_foco = false;
function foco(id = false) {
  console.log(s_foco);
  if(id){
    s_foco = id;
    $(id).css('z-index', '9999999999999');
    $('#mdl-back').modal('show');
  }else{
    $(s_foco).css('z-index', '0');
    $('#mdl-back').modal('hide');
  }
}

function conf(fun, e, pregunta = 'Confirma realizar esta acción?', msj = "Esta acción no se pordrá revertir") {
  Swal.fire({
      title: pregunta,
      text: msj,
      type: "warning",
      showCancelButton: true,
      confirmButtonColor: "#3085d6",
      cancelButtonColor: "#d33",
      confirmButtonText: "Si",
      cancelButtonText: 'No, Cancelar!'
  }).then((result) => {
      if (result.value) {
          fun(e);
      }
  });
}
//Funcion para confirmar el cierre, asi salta el swal antes de refrescar la pantalla
function confRefresh(fun, e = '', msj = "Se finalizó la tarea correctamente!") {
  Swal.fire({
    title: 'Perfecto!',
    text: msj,
    type: 'success',
    showCancelButton: false,
    confirmButtonText: 'Hecho'
  }).then((result) => {
      if (result.value) {
        if(_isset(e)){
          fun(e);
        }else{
          fun();
        }
      }
  });
}