<!-- /// ---- HEADER ----- /// -->
<div class="box box-primary animated fadeInLeft">
    <div class="box-header with-border">
        <h4>Lista de Transportistas</h4>
    </div>
    <div class="box-body">
        <div class="row">
            <div class="col-md-2 col-lg-1 col-xs-12">
                <button type="button" id="botonAgregar" class="btn btn-primary" aria-label="Left Align">
                    Agregar
                </button><br>
            </div>
            <div class="col-md-10 col-lg-11 col-xs-12"></div>
        </div>
    </div>
</div>
<!-- /// ----- HEADER -----/// -->

<!--_______ FORMULARIO TRANSPORTISTAS______-->
<div class="box box-primary animated bounceInDown" id="boxDatos" hidden>
    <div class="box-header with-border">
        <div class="box-tittle">
            <h4>Nuevo Transportista</h4>
        </div>
        <div class="box-tools pull-right border ">
            <button type="button" id="btnclose" title="cerrar" class="btn btn-box-tool" data-widget="remove" data-toggle="tooltip" title="" data-original-title="Remove">
                <i class="fa fa-times"></i>
            </button>
        </div>
    </div>
    <!--_____________________________________________-->
    <div class="box-body">
        <form class="formTransportistas" id="formTransportistas">
            <!--Razón social-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Razon_social">Razón social(<strong style="color: #dd4b39">*</strong>):</label>
                    <input type="text" class="form-control requerido" name="razon_social" id="razon_social" placeholder="Ingrese razón social...">
                </div>
            </div>
            <!--________________-->
            <!-- CUIT -->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Cuit">Cuit:</label>
                    <input type="text" class="form-control" name="cuit" id="cuit" placeholder="Ingrese cuit..." onkeyup="validarCuit()">
                </div>
                <div class="form-group">
                    <!--<input style="display:none;" type="text" class="form-control" name="cuitValid" id="cuitValid" placeholder="cuitvalid">-->
                    <div id="cuitValid" onclick="validarCuit()">

                    </div>
                </div>
            </div>
            <!--________________-->

            <!--Teléfono-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Telefono">Teléfono:</label>
                    <input type="text" class="form-control" name="telefono" id="telefono" placeholder="Ingrese teléfono...">
                </div>
            </div>
            <!--________________-->
            <!--Email-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Email">Email:</label>
                    <input type="text" class="form-control" name="email" id="email" placeholder="Ingrese email...">
                </div>
            </div>
            <!--________________-->
            <!--Dirección-->
            <div class="col-md-12 col-sm-12 col-xs-12">
                <div class="form-group">
                    <label for="Direccion">Dirección:</label>
                    <input type="text" class="form-control" name="direccion" id="direccion" placeholder="Ingrese dirección...">
                </div>
            </div>
            <!--________________-->
            <!--País-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Pais">País:</label>
                    <select onchange="seleccionPais()" class="form-control select select-hidden-accesible" name="pais_id" id="pais_id" style='width: 100%;'>
                        <option value="" disabled selected>-Seleccione País-</option>
                        <?php
                        foreach ($listarPaises as $pais) {
                            echo '<option  value="' . $pais->tabl_id . '">' . $pais->valor . '</option>';
                        }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Estado-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Estado">Estado:</label>
                    <select onchange="seleccionEstado()" class="form-control select select-hidden-accesible habilitar" name="prov_id" id="prov_id" style='width: 100%;'>
                        <option value="" disabled selected>-Seleccione Estado/Provincia-</option>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Localidad-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Localidad">Localidad:</label>
                    <select class="form-control select select-hidden-accesible habilitar" name="loca_id" id="loca_id" style='width: 100%;'>
                        <option value="" disabled selected>-Seleccione Localidad-</option>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Tipo de transporte-->
            <div class="col-md-6 col-sm-6 col-xs-12">
                <div class="form-group">
                    <label for="Tipo_transporte">Tipo de transporte:</label>
                    <select class="form-control select select-hidden-accesible" name="tipo_transporte" id="tipo_transporte" style='width: 100%;'>
                        <option value="" disabled selected>-Seleccione Tipo de transporte-</option>
                        <?php
                        foreach ($tipos_transporte as $tipo) {
                            echo '<option  value="' . $tipo->tabl_id . '">' . $tipo->valor . '</option>';
                        }
                        ?>
                    </select>
                </div>
            </div>
            <!--________________-->
            <!--Observaciones-->
            <div class="col-md-12 col-sm-12 col-xs-12">
                <div class="form-group">
                    <label for="Observaciones">Observaciones:</label>
                    <textarea rows="3" class="form-control" name="observaciones" id="observaciones" placeholder="Ingrese observaciones..."></textarea>
                </div>
            </div>
            <!--________________-->
        </form>
    </div>
    <!--_________________ GUARDAR_________________-->
    <div class="modal-footer">
        <div class="form-group text-right">
            <button type="button" class="btn btn-primary" onclick="guardar('nueva')" id="save">Guardar</button>
        </div>
    </div>
    <!--__________________________________-->
</div>
<!--_______ FIN FORMULARIO TRANSPORTISTAS ______-->

<!---/////---BOX 2 DATATBLE ---/////----->
<div class="box box-primary">
    <div class="box-body">
        <div id="example2_wrapper" class="dataTables_wrapper form-inline dt-bootstrap">
            <div class="row">
                <div class="col-sm-6"></div>
                <div class="col-sm-6"></div>
            </div>
            <div class="row">
                <div class="col-sm-12 table-scroll" id="cargar_tabla">
                </div>
            </div>
        </div>
    </div>
</div>
<!---/////--- FIN BOX 2 DATATABLE---//////----->

<!---///////--- MODAL EDICION E INFORMACION ---///////--->
<div class="modal fade bs-example-modal-lg" id="modaleditar" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header bg-blue">
                <button type="button" class="close close_modal_edit" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true" style="color:white;">&times;</span>
                </button>
            </div>
            <div class="modal-body ">
                <form class="formEdicion" id="formEdicion">
                    <div class="form-horizontal">
                        <div class="row">
                            <form class="frm_transportista_edit" id="frm_transportista_edit">
                                <input type="text" class="form-control habilitar hidden" name="tran_id" id="tran_id_edit">
                                <!--_____________ RAZON SOCIAL _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="razon_social_edit">Razón social(<strong style="color: #dd4b39">*</strong>):</label>
                                        <input type="text" class="form-control habilitar requerido" name="razon_social" id="razon_social_edit">
                                    </div>
                                </div>
                                <!--___________________________-->
                                <!--_____________ CUIT _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="cuit_edit">Cuit:</label>
                                        <input type="text" class="form-control habilitar" name="cuit" id="cuit_edit">
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ TELEFONO _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="telefono_edit">Teléfono:</label>
                                        <input type="text" class="form-control habilitar" name="telefono" id="telefono_edit">
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ EMAIL _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="email_edit">Email:</label>
                                        <input type="text" class="form-control habilitar" name="email" id="email_edit">
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ DIRECCION _____________-->
                                <div class="col-sm-12">
                                    <div class="form-group col-sm-12">
                                        <label for="direccion_edit">Dirección:</label>
                                        <input type="text" class="form-control habilitar" name="direccion" id="direccion_edit">
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ PAIS _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="pais_id_edit">País:</label>
                                        <select onchange="seleccionPaisEditar()" class="form-control select select-hidden-accesible selec_habilitar" name="pais_id" id="pais_id_edit" style='width: 100%;'>
                                            <option value="" disabled selected>-Seleccione País-</option>
                                            <?php
                                            foreach ($listarPaises as $pais) {
                                                echo '<option  value="' . $pais->tabl_id . '">' . $pais->valor . '</option>';
                                            }
                                            ?>
                                        </select>
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ ESTADO _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="prov_id_edit">Estado:</label>
                                        <select onchange="seleccionEstadoEditar()" class="form-control select select-hidden-accesible selec_habilitar" name="prov_id" id="prov_id_edit" style='width: 100%;'>
                                            <option value="" disabled selected>-Seleccione Estado/Provincia-</option>
                                        </select>
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ LOCALIDAD _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="loca_id_edit">Localidad:</label>
                                        <select class="form-control select select-hidden-accesible selec_habilitar" name="loca_id" id="loca_id_edit" style='width: 100%;'>
                                            <option value="" disabled selected>-Seleccione Localidad-</option>
                                        </select>
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ TIPO DE TRANSPORTE _____________-->
                                <div class="col-sm-6">
                                    <div class="form-group col-sm-12">
                                        <label for="tipo_transporte_edit">Tipo de transporte:</label>
                                        <select class="form-control select select-hidden-accesible selec_habilitar" name="tipo_transporte" id="tipo_transporte_edit" style='width: 100%;'>
                                            <option value="" disabled selected>-Seleccione Tipo de transporte-</option>
                                            <?php
                                            foreach ($tipos_transporte as $tipo) {
                                                echo '<option  value="' . $tipo->tabl_id . '">' . $tipo->valor . '</option>';
                                            }
                                            ?>
                                        </select>
                                    </div>
                                </div>
                                <!--__________________________-->
                                <!--_____________ OBSERVACIONES _____________-->
                                <div class="col-sm-12">
                                    <div class="form-group col-sm-12">
                                        <label for="observaciones_edit">Observaciones:</label>
                                        <textarea rows="3" class="form-control habilitar" name="observaciones" id="observaciones_edit" placeholder="Ingrese observaciones..."></textarea>
                                    </div>
                                </div>
                                <!--__________________________-->
                            </form>
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <div class="form-group text-right">
                    <button type="" class="btn btn-primary habilitar" data-dismiss="modal" id="btnsave_edit" onclick="guardar('editar')">Guardar</button>
                    <button type="" class="btn btn-default cerrarModalEdit" id="" data-dismiss="modal">Cerrar</button>
                </div>
            </div>
        </div>
    </div>
</div>
<!---///////--- FIN MODAL EDICION E INFORMACION ---///////--->
<script>
    // carga tabla genaral de transportistas
    $("#cargar_tabla").load("index.php/core/Transportista/Listar_Transportistas");

    // muestra box de datos al dar click en boton agregar
    $("#botonAgregar").on("click", function() {
        $("#botonAgregar").attr("disabled", "");
        //$("#boxDatos").removeAttr("hidden");
        $("#boxDatos").focus();
        $("#boxDatos").show();
    });

    // muestra box de datos al dar click en X
    $("#btnclose").on("click", function() {
        $("#boxDatos").hide(500);
        $("#botonAgregar").removeAttr("disabled");
        //$('#formDatos').data('bootstrapValidator').resetForm();
        $("#formDatos")[0].reset();
    });

    // valida campos obligatorios
    function validarCampos(form) {
        var mensaje = "";
        var ban = true;
        $('#' + form).find('.requerido').each(function() {
            if (this.value == "" || this.value == "-1") {
                ban = ban && false;
                return;
            }
        });
        if (!ban) {
            if (!alertify.errorAlert) {
                alertify.dialog('errorAlert', function factory() {
                    return {
                        build: function() {
                            var errorHeader = '<span class="fa fa-times-circle fa-2x" ' +
                                'style="vertical-align:middle;color:#e10000;">' +
                                '</span>Error...!!';
                            this.setHeader(errorHeader);
                        }
                    };
                }, true, 'alert');
            }
            alertify.errorAlert("Por favor complete los campos Obligatorios(*)...");
        }
        return ban;
    }
    // valida que CUIT no este repetido
    function validarCuit() {

        let datos = $("#cuit").val();
        if (!datos) {
            $("#cuitValid").html("");
            return false;
        } else {
            $.ajax({
                type: 'POST',
                data: {
                    datos
                },
                dataType: 'JSON',
                url: 'index.php/core/Transportista/Validar_Cuit',
                success: function(resp) {
                    const data = JSON.parse(resp.data);
                    const {
                        transportista
                    } = data.transportistas;                   

                    //validos si el objeto viene vacio 

                    ($.isEmptyObject(transportista)) ? $("#cuitValid").html(""): $("#cuitValid").html(`<div class="alert alert-danger" role="alert">CUIT EXISTENTE</div>`);

                },
                error: function(error) {

                }
            });
        }


    }
    //Alta de transportista en sistmea
    function guardar(operacion) {
        var recurso = "";
        if (operacion == "editar") {
            if (!validarCampos('formEdicion')) {
                return;
            }
            $("#prov_id_edit").prop('disabled', false);
            $("#loca_id_edit").prop('disabled', false);
            var form = $('#formEdicion')[0];
            var datos = new FormData(form);
            var datos = formToObject(datos);
            recurso = 'index.php/core/Transportista/Editar_Transportista';
        } else {
            if (!validarCampos('formTransportistas')) {
                return;
            }
            var form = $('#formTransportistas')[0];
            var datos = new FormData(form);
            var datos = formToObject(datos);
            recurso = 'index.php/core/Transportista/Guardar_Transportista';
        }
        wo();
        $.ajax({
            type: 'POST',
            data: {
                datos
            },
            dataType: 'JSON',
            url: recurso,
            success: function(resp) {
                $("#boxDatos").hide(500);
                $("#formTransportistas")[0].reset();
                $("#botonAgregar").removeAttr("disabled");
                if (resp.status) {
                    $("#cargar_tabla").load("index.php/core/Transportista/Listar_Transportistas", () => {
                        if (operacion == "editar") {
                            hecho('Correcto!', resp.message);
                            wc();
                        } else {
                            hecho('Correcto!', resp.message);
                            wc();
                        }
                    });
                } else {
                    error('Error!', resp.message);
                    wc();
                }
            },
            error: function(resp) {
                wc();
                alertify.error("Error agregando Transportista");
            }
        });
    }

    /* carga Estados dependiendo del pais seleccionado*/
    function seleccionPais() {
        var id_pais = $("#pais_id option:selected").text();
        $("#prov_id_edit").prop('disabled', false);
        wo();
        $.ajax({
            type: 'POST',
            // dataType: "json",
            data: {
                id_pais: id_pais
            },
            url: 'index.php/core/Transportista/getEstados',
            success: function(rsp) {
                var resp = JSON.parse(rsp);
                $('#prov_id').empty();
                $('#loca_id').empty();
                if (resp != null) {
                    /* habilitarEdicion(); */
                    var datos = "<option value='' disabled selected>-Seleccione Estado/Provincia-</option>";
                    for (let i = 0; i < resp.length; i++) {
                        var datito = encodeURIComponent(resp[i].tabl_id);
                        datos += "<option value=" + datito + ">" + resp[i].valor + "</option>";
                    }
                    $('#prov_id').html(datos);
                    var datos = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    $('#loca_id').html(datos);
                } else {
                    var provincia = "<option value='' disabled selected>-Seleccione Estado/Provincia-</option>";
                    $('#prov_id').html(provincia);
                    var localidad = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    $('#loca_id').html(localidad);
                    alertify.error("El País no contiene estados");
                }
                wc();
            },
            error: function(data) {
                wc();
                alert('Error');
            }
        });
    }

    /* carga Localidades dependiendo del estado seleccionado*/
    function seleccionEstado() {
        var id_pais = $("#pais_id option:selected").text();
        var id_estado = $("#prov_id option:selected").text();
        wo();
        $.ajax({
            type: 'POST',
            // dataType: "json",
            data: {
                id_pais,
                id_estado
            },
            url: 'index.php/core/Transportista/getLocalidades',
            success: function(rsp) {
                var resp = JSON.parse(rsp);
                $('#loca_id').empty();
                if (resp != null) {
                    /* habilitarEdicion(); */
                    var datos = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    for (let i = 0; i < resp.length; i++) {
                        var valor = encodeURIComponent(resp[i].tabl_id);
                        datos += "<option value=" + valor + ">" + resp[i].valor + "</option>";
                    }
                    $('#loca_id').html(datos);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    $('#loca_id').html(datos);
                    alertify.error("El Estado no contiene localidades");
                }
                wc();
            },
            error: function(data) {
                wc();
                alert('Error');
            }
        });
    }

    /* carga Estados dependiendo del pais seleccionado*/
    function seleccionPaisEditar() {
        var id_pais = $("#pais_id_edit option:selected").text();
        // $("#prov_id_edit").prop('disabled', false);
        wo();
        $.ajax({
            type: 'POST',
            // dataType: "json",
            data: {
                id_pais: id_pais
            },
            url: 'index.php/core/Transportista/getEstados',
            success: function(rsp) {
                var resp = JSON.parse(rsp);
                $('#prov_id_edit').empty();
                $('#loca_id_edit').empty();
                if (resp != null) {
                    /* habilitarEdicion(); */
                    var datos = "<option value='' selected>-Seleccione Estado/Provincia-</option>";
                    for (let i = 0; i < resp.length; i++) {
                        var datito = encodeURIComponent(resp[i].tabl_id);
                        datos += "<option value=" + datito + ">" + resp[i].valor + "</option>";
                    }
                    $('#prov_id_edit').html(datos);
                    $("#prov_id_edit").prop('disabled', false);
                    var datos = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    $('#loca_id_edit').html(datos);
                } else {
                    var provincia = "<option value='' disabled selected>-Seleccione Estado/Provincia-</option>";
                    $('#prov_id_edit').html(provincia);
                    var localidad = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    $('#loca_id_edit').html(localidad);
                    $("#prov_id_edit").prop('disabled', true);
                    alertify.error("El País no contiene estados");
                }
                wc();
            },
            error: function(data) {
                wc();
                alert('Error');
            }
        });
    }

    /* carga Localidades dependiendo del estado seleccionado*/
    function seleccionEstadoEditar() {
        var id_pais = $("#pais_id_edit option:selected").text();
        var id_estado = $("#prov_id_edit option:selected").text();
        wo();
        $.ajax({
            type: 'POST',
            // dataType: "json",
            data: {
                id_pais,
                id_estado
            },
            url: 'index.php/core/Transportista/getLocalidades',
            success: function(rsp) {
                var resp = JSON.parse(rsp);
                $('#loca_id_edit').empty();
                if (resp != null) {
                    /* habilitarEdicion(); */
                    var datos = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    for (let i = 0; i < resp.length; i++) {
                        var valor = encodeURIComponent(resp[i].tabl_id);
                        datos += "<option value=" + valor + ">" + resp[i].valor + "</option>";
                    }
                    $('#loca_id_edit').html(datos);
                    $("#loca_id_edit").prop('disabled', false);
                } else {
                    var datos = "<option value='' disabled selected>-Seleccione Localidad-</option>";
                    $('#loca_id_edit').html(datos);
                    $("#loca_id_edit").prop('disabled', true);
                    alertify.error("El Estado no contiene localidades");
                }
                wc();
            },
            error: function(data) {
                wc();
                alert('Error');
            }
        });
    }
</script>