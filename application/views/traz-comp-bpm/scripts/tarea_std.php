<script>
//Script para Vista Standar  
evaluarEstado();

function evaluarEstado() {

    if (task.idUsuarioAsignado != "") {
        habilitar();
    } else {
        deshabilitar();
    }
}

function habilitar() {

    $(".btn-soltar").show();
    $(".btn-tomar").hide();
    $('#view').css('pointer-events', 'auto');
}

function deshabilitar() {
    $(".btn-soltar").hide();
    $(".btn-tomar").show();
    //$('#view').css('pointer-events', 'none');
}

function tomarTarea() {
    wo();

    $.ajax({
        type: 'POST',
        data: {
            id: task.taskId
        },
        url: 'index.php/<?php echo BPM ?>Tarea/tomarTarea',
        success: function(data) {

            if (data['status']) {
                habilitar();
            } else {
                alert(data['msj']);
            }

        },
        error: function(result) {
            alert('Error');
        },
        dataType: 'json',
         complete:function(){
            wc();
        }
    });
}
// Soltar tarea en BPM
function soltarTarea() {

    alert('Soltar');
    wo();
    $.ajax({
        type: 'POST',
        data: {
            id: task.taskId
        },
        url: 'index.php/<?php echo BPM ?>Tarea/soltarTarea',
        success: function(data) {

            // toma a tarea exitosamente
            if (data['status']) {
                deshabilitar();
            }
        },
        error: function(result) {
            console.log(result);
        },
        dataType: 'json',
         complete:function(){
            wc();
        }
    });
}

function cerrar() {
    if ($('#miniView').length == 0) {
        linkTo('<?php echo BPM ?>Tarea');
    } else {
        if(existFunction('closeView')) closeView();
    }
}

//Funcion COMENTARIOS
function guardarComentario() {

debugger;
var comentario = $('#comentario').val();
if (comentario.length == 0 ) {
                
Swal.fire({
            type: 'error',
            title: 'Error...',
            text: 'Asegurate de escribir un comentario!',
            footer: ''
            });
    
    return;

            }
            else{

console.log("Guardar Comentarios...");
var id = $('#case_id').val();
var comentario = $('#comentario').val();
var nombUsr = $('#usrName').val();
var apellUsr = $('#usrLastName').val();;
$.ajax({
    type: 'POST',
    data: {
        'processInstanceId': id,
        'content': comentario
    },
    url: '<?php echo base_url(BPM) ?>Proceso/guardarComentario',
    success: function(result) {
        console.log("Submit");
        var lista = $('#listaComentarios');
        lista.prepend('<hr/><li><h4>' + nombUsr + ' ' + apellUsr +
            '<small style="float: right">Hace un momento</small></h4><p>' + comentario + '</p></li>'
            );
        $('#comentario').val('');
    },
    error: function(result) {
        console.log("Error");
    }
});
}
}


//COMENTARIOS VIEJOS
// function guardarComentario() {
//     var nombUsr = $('#usrName').val();
//     var apellUsr = $('#usrLastName').val();
//     var comentario = $('#comentario').val();
//     wo();
//     $.ajax({
//         type: 'POST',
//         data: {
//             'processInstanceId': task.caseId,
//             'content': comentario
//         },
//         url: '',
//         success: function(result) {
//             var lista = $('#listaComentarios');
//             lista.prepend(
//                 '<div class="item"><p class="message"><a href="#" class="name"><small class="text-muted pull-right"><i class="fa fa-clock-o"></i> 2:15</small>' +
//                 nombUsr + ' ' + apellUsr +
//                 '</a><br><br>' + comentario + '</p></div>'

//             );
//             $('#comentario').val('');
//         },
//         error: function(result) {
//             console.log("Error");
//         },
//         complete:function(){
//             wc();
//         }
//     });
// }
</script>