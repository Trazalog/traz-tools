function frmValidar(id = false) {
	if (!id) {
		var btnForms = $(".btn-form").length;
		if (btnForms == 0) return true; //No hay forms

		var forms = $("#frm-list form");
		if (forms.length < btnForms) return false; //No se abrieron todos los Forms

		//Todos los Forms se abrieron y se verifica si todos fueron validados
		var ban = true;
		forms.each(function () {
			ban = ban && this.dataset.valido == "true";
		});

		if (!ban) console.log("FRM | Formularios No Válidos");

		return ban;
	} else {
		return $("#" + id).data("valido") == "true";
	}
}

function initForm() { 
	$("form").each(function () {
		$(this)
			.bootstrapValidator({
				feedbackIcons: {
					valid: "glyphicon glyphicon-ok",
					invalid: "glyphicon glyphicon-remove",
					validating: "glyphicon glyphicon-refresh",
				},
				fields: {
					select: {
						selector: ".frm-select",
						validators: {
							callback: {
								message: "Seleccionar Opción",
								callback: function (value, validator, $field) {
							
									if (value == "" || value == "0") {
										return false;
									} else {
										return true;
									}
								},
							},
						},
					},
				},
			})
			.on("success.form.bv", function (e) {
				e.preventDefault();
			});
	});

	$(".datepicker").datepicker({
		dateFormat: "yy-mm-dd",
	});

	$('input[type="checkbox"].flat-red, input[type="radio"].flat-red').iCheck({
		checkboxClass: "icheckbox_flat-green",
		radioClass: "iradio_flat-green",
	});

	$('input[type="file"]').on("change", function (e) {
		var filename = $(this).val();

		if (filename != "" && filename != null) {
			var link = $(this).closest(".form-group").find("a").show();
			var file = e.target.files[0];
			var filename = e.target.files[0].name;
			var blob = new Blob([file]);
			var url = URL.createObjectURL(blob);

			$(link).find("a").attr({
				download: filename,
				href: url,
			});
		}
	});
}


function frm_validar(id) {
	$(id).bootstrapValidator("validate");
	return $(id).data("bootstrapValidator").isValid();
}

function frmGuardar(e,accionPosGuardado = false,mostrarAlerta = true) {
	wo();

	var form = $(e).closest("form").attr("id");
	var info = $(e).closest("form").data("info");

	var nuevo = info == "";
	if (nuevo) info = $(e).closest("form").data("form");

	$("#" + form).bootstrapValidator("validate");

	var bv = $("#" + form).data("bootstrapValidator");

	$("#" + form).attr("data-valido", bv.isValid() ? "true" : "false");

	var formData = new FormData($("#" + form)[0]);

	//Preparo Informacion Checkboxs
	var checkbox = $("#" + form).find("input[type=checkbox]");
	$.each(checkbox, function (key, val) {
		if (!formData.has($(val).attr("name"))) {
			formData.append($(val).attr("name"), "");
		}
	});

	//Preparo Informacion Files
	var files = $("#" + form + ' input[type="file"]');
	files.each(function () {
		if (conexion()) {
			if (this.value != null && this.value != "")
				formData.append(this.name, this.value);
		} else {
			formData.delete(this.name);
		}
	});

	var json = formToJson(formData);

	//guardarEstado($('#task').val() + '_frm', json, '#' + form);

	if (!conexion()) {
		wc();

		console.log("Offline | Formulario Guardado...");

		$("#" + form)
			.closest(".modal")
			.modal("hide");

		ajax({
			type: "POST",
			dataType: "JSON",
			url: "index.php/" + frmUrl + "Form/guardarJson/" + info,
			data: {
				json,
			},
			success: function (rsp) {},
			error: function (rsp) {},
		});
	} else {
		$.ajax({
			type: "POST",
			dataType: "JSON",
			cache: false,
			contentType: false,
			processData: false,
			url:
				"index.php/" + frmUrl + "Form/guardar/" + info + (nuevo ? "/true" : ""),
			data: formData,
			success: function (rsp) {
				$("#" + form).closest(".modal").modal("hide");
				wc();
				if(_isset(rsp.info_id)){
					if(accionPosGuardado)accionPosGuardado(rsp.info_id);
				}

				if(mostrarAlerta) Swal.fire('Guardado!','El registro se guardó correctamente','success')
			},
			error: function (rsp) {
				console.log("Error al guardar Formulario");
				Swal.fire(
					'Oops...',
					'No se guardó formulario',
					'error'
				);
				wc();
			}
		});
	}
}

function detectarForm() {
	$(".frm-open").click(function () {
		// if (isModalOpen()) return;

		// obtenerForm(this.dataset.info);

		$(this).load(
			"index.php/" + frmUrl + "Form/obtener/" + this.dataset.info,
			function () {
				$(".frm-select").select2();
			}
		);
	});

	$(".frm-new-modal").click(function () {
		nuevoForm(this.dataset.form);
	});

	$(".frm-new").each(function () {
		$(this).load(
			"index.php/" + frmUrl + "Form/obtenerNuevo/" + this.dataset.form,
			function () {
				$(".frm-select").select2();
			}
		);
	});
}

function nuevoForm(form, show = true) {
	wo();
	$.ajax({
		type: "GET",
		dataType: "JSON",
		url: "index.php/" + frmUrl + "Form/obtenerNuevo/" + form + "/" + modal,
		success: function (rsp) {
			if (modal) {
				$("#frm-list").append(rsp.html);

				if (show) $("#frm-modal-").modal("show");
				$("#frm-modal- .btn-accion").click(function () {
					$(this).closest(".modal").find(".frm-save").click();
				});
			}

			initForm();
		},
		error: function (rsp) {
			console.log("Error al Obtener Formulario");
		},
		complete: function () {
			wc();
		},
	});
}

function obtenerForm(info, show = true) {
	wo();
	$.ajax({
		type: "GET",
		dataType: "JSON",
		url: "index.php/" + frmUrl + "Form/obtener/" + info + "/" + modal,
		success: function (rsp) {
			if (modal) {
				$("#frm-modal-" + info).remove();
				$("#frm-list").append(rsp.html);

				if (!conexion()) {
					console.log("Offiline | Sin Conexión...");

					var task = $("#task").val();
					var id = "#frm-" + info;
					var aux = JSON.parse(sessionStorage.getItem(task + "_frm"));
					if (aux != null) {
						if (aux[id] != null) {
							var form = JSON.parse(aux[id]);

							console.log("Offline | Abriendo Estado Intermedio Formulario");

							Object.keys(form).forEach(function (key) {
								//Tipo Checks
								if (key.includes("[]")) {
									$(id + ' [name="' + key + '"]').each(function () {
										this.checked = form[key].includes(this.value);
									});
								} else {
									var input = $(id + ' [name="' + key + '"]')[0];

									//Ignorar Tipos Files
									if (input.getAttribute("type") == "file") return;

									//Radio
									if (
										input.getAttribute("type") == "radio" &&
										input.value == form[key]
									) {
										input.checked = true;
										return;
									}
									console.log(input.tagName);
									if (input.tagName == "TEXTAREA") {
										alert("colis");
										$(id + ' [name="' + key + '"]').html(form[key]);
										return;
									}

									//Default
									$(id + ' [name="' + key + '"]').val(form[key]);
								}
							});
						}
					}
				}
				if (show) $("#frm-modal-" + info).modal("show");
				$("#frm-modal-" + info + " .btn-accion").click(function () {
					$(this).closest(".modal").find(".frm-save").click();
				});
			}

			initForm();
		},
		error: function (rsp) {
			console.log("Error al Obtener Formulario");
		},
		complete: function () {
			wc();
		},
	});
}

function getForm(form) {
	const data = new FormData($(form)[0]);
	return formToObject(data);
}

function formToJson(formData) {
	var object = {};

	formData.forEach((value, key) => {
		if (!object.hasOwnProperty(key)) {
			object[key] = value;
			return;
		}

		if (!Array.isArray(object[key])) {
			object[key] = [object[key]];
		}

		object[key].push(value);
	});

	return JSON.stringify(object);
}

function formToObject(formData) {
	return JSON.parse(formToJson(formData));
}

function showFD(formData) {
	for (var pair of formData.entries()) {
		console.log(pair[0] + ", " + pair[1]);
	}
}

function mergeFD(f1, f2) {
	for (var pair of f2.entries()) {
		f1.append(pair[0], pair[1]);
	}
	return f1;
}

function getJson(e) {
	var json = $(e).attr("data-json");
	if (json == null || json == "") return false;
	return JSON.parse(json);
}

function validar(e) {
	
	var ban = true;

	$(e)
		.find(".req")
		.each(function () {
			ban = ban && !(this.value == "" || this.value == null);
		});

	return ban;
}


function b64_to_utf8(str) {
	return decodeURIComponent(escape(window.atob(str)));
  }


function fillForm(data, form = false){
	
  Object.keys(data).forEach(e => {

      if(form){
		var obj = $(form).find('[name="' + e + '"]')[0];
      }else{
		var obj = $('[name="' + e + '"]')[0];
      }
	  
      if (!obj) return; 

      switch (obj.getAttribute('type')) {
          case 'radio':
              const aux = $('[name="' + e + '"][value="' + data[e] + '"]')[0];
              aux.checked = true;
              break;
          case 'checkbox':
              obj.checked = data[e]=="1";
			  $(obj).iCheck('update');
		  case 'file':
			dato = data[e];

		if ( dato !='') {
			/*console.log('tu hermana');*/
			dato = data[e];
			let decodificado = b64_to_utf8(dato);
				console.log(decodificado);
			$(obj).addClass('hidden');
				$(obj).closest('.form-group').find('.help-block').html(`<a download='documento.png' href='data:image/png;base64,${decodificado}' id='descarga_documento'>Click para descargar</a>`);
		} else{
			$(obj).addClass('hidden');
			$(obj).closest('.form-group').find('.help-block').html(`<a href='${data[e]}' id='descarga_documento'>Click para descargar/a>`);
		
		}

			break;
      
          default:
			  obj.value = data[e];
			  
              break;
	  }
	});
	$(form).find('select').select2().trigger('change');
}

function frmReset(id) {
	var bv = $(id).data('bootstrapValidator');
	if(bv) bv.resetForm();
	$(id)[0].reset();
}

function previewFile(input) {
    if(input.files && input.files[0]){
        var idImagen = $(input).attr('id');
        var reader = new FileReader();

        reader.addEventListener("load", function (e) {
            $('#vistaPrevia_'+idImagen).css('background-image', 'url('+e.target.result +')');
            $('#vistaPrevia_'+idImagen).hide();
            $('#vistaPrevia_'+idImagen).fadeIn(850);   
        }, false);

        reader.readAsDataURL(input.files[0]);
    }
}
//Funcion para guardar el formulario dinamico con promesas y retornando el info_id generado
async function frmGuardarConPromesa(e) {
    var form = $(e).closest("form").attr("id");
	var info = $(e).closest("form").data("info");

	var nuevo = info == "";
	if (nuevo) info = $(e).closest("form").data("form");
    var formData = new FormData($("#" + form)[0]);

    //Preparo Informacion Checkboxs
	var checkbox = $("#" + form).find("input[type=checkbox]");
	$.each(checkbox, function (key, val) {
		if (!formData.has($(val).attr("name"))) {
			formData.append($(val).attr("name"), "");
		}
	});

	//Preparo Informacion Files
	var files = $("#" + form + ' input[type="file"]');
	files.each(function () {
		if (conexion()) {
			if (this.value != null && this.value != "")
				formData.append(this.name, this.value);
		} else {
			formData.delete(this.name);
		}
	});
    let guardadoFormDinamico = new Promise((resolve,reject) => {
        $.ajax({
            type: "POST",
            dataType: "JSON",
            cache: false,
            contentType: false,
            processData: false,
            url:
                "index.php/" + frmUrl + "Form/guardar/" + info + (nuevo ? "/true" : ""),
            data: formData,
            success: function (rsp) {
                if(_isset(rsp.info_id)){
                    resolve(rsp.info_id);
                }else{
                    reject("Ocurrió un error al gurdar el formulario dinámico");
                }  
            },
            error: function (rsp) {
                Swal.fire('Oops...','No se guardo formulario dinámico','error');
                reject("Ocurrió un error al gurdar el formulario dinámico");
            }
        });
    });
    return await guardadoFormDinamico;
}


// Nueva función para guardar formulario dinámico - en realidad guarda un formulario nuevo 
async function editarFormulario($form) {
    
    // Obtener información del formulario
    var formId = $form.attr("id");
    var info = $form.data("info");
    var nuevo = info == "";
    if (nuevo) info = $form.data("form");

    // CORRECCIÓN: Construir FormData manualmente con valores actuales
    var formData = new FormData();
    
    // Agregar todos los campos del formulario con sus valores actuales
    $form.find('input, select, textarea').each(function() {
        var $element = $(this);
        var name = $element.attr('name');
        var type = $element.attr('type');
        var tagName = $element.prop('tagName').toLowerCase();
        
        if (!name) return; // Saltar elementos sin name
        

        // Para campos de texto, email, number, hidden, etc.
        if (type !== 'file' && type !== 'checkbox' && type !== 'radio') {
            if (tagName === 'select') {
                // Para selects múltiples
                if ($element.prop('multiple')) {
                    var values = $element.val() || [];
                    values.forEach(function(value) {
                        formData.append(name + '[]', value);
                    });
                    console.log(`Select múltiple ${name}:`, values);
                } else {
                    // Para select simple
                    formData.append(name, $element.val() || '');
                    console.log(`Select simple ${name}:`, $element.val());
                }
            } else {
                // Para inputs y textareas
                formData.append(name, $element.val() || '');
                console.log(`Input/Textarea ${name}:`, $element.val());
            }
        }
        // Para checkboxes
        else if (type === 'checkbox') {
            var value = $element.is(':checked') ? 'on' : 'off';
            formData.append(name, value);
            console.log(`Checkbox ${name}:`, value);
        }
        // Para radios
        else if (type === 'radio') {
            if ($element.is(':checked')) {
                formData.append(name, $element.val());
                console.log(`Radio ${name}:`, $element.val());
            }
        }
    });

    // Preparar Información Checkboxs (por si hay alguno que no se capturó)
    var checkbox = $form.find("input[type=checkbox]");
    $.each(checkbox, function (key, val) {
        var $checkbox = $(val);
        var name = $checkbox.attr("name");
        if (name && !formData.has(name)) {
            formData.append(name, $checkbox.is(':checked') ? 'on' : 'off');
            console.log(`Checkbox adicional ${name}:`, $checkbox.is(':checked'));
        }
    });

    // Preparar Información Files
    var files = $form.find('input[type="file"]');
    files.each(function () {
        var $file = $(this);
        var name = $file.attr("name");
        if (conexion()) {
            if (this.files && this.files[0]) {
                formData.append(name, this.files[0]);
                console.log(`Archivo ${name}:`, this.files[0].name);
            } else if (this.value) {
                formData.append(name, this.value);
                console.log(`Archivo valor ${name}:`, this.value);
            }
        } else {
            formData.delete(name);
        }
    });

    let guardadoFormDinamico = new Promise((resolve, reject) => {
        $.ajax({
            type: "POST",
            dataType: "JSON",
            cache: false,
            contentType: false,
            processData: false,
            url: "index.php/" + frmUrl + "Form/guardar/" + info + (nuevo ? "/true" : ""),
            data: formData,
            success: function (rsp) {
                console.log('Respuesta del servidor:', rsp);
                if(_isset(rsp.info_id)){
                    resolve(rsp.info_id);
                } else {
                    reject("Ocurrió un error al guardar el formulario dinámico - Sin info_id");
                }  
            },
            error: function (rsp) {
                console.error('Error en AJAX:', rsp);
                Swal.fire('Oops...','No se guardó formulario dinámico','error');
                reject("Ocurrió un error al guardar el formulario dinámico - Error AJAX");
            }
        });
    });
    
    return await guardadoFormDinamico;
}