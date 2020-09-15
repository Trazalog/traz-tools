<!---//////////////////////////////////////--- FORMULARIO 1 ---///////////////////////////////////////////////////////----->


<div class="box box-primary">

    <!--____________________ BOX HEADER _________________________-->

    <div class="box-header with-border">
        <div class="box-tittle">
            <h3>FORMULARIO 2 COLUMNAS</h3>
        </div>
    </div>

    <!--__________________ BOX BODY __________________________-->

    <div class="box-body">

        <!-- /// ----------------------------------- FORMULARIO ----------------------------------- /// -->

        <form class="formNombre1" id="IDnombre">

            <!-- ____________________________ GRUPO 1 ____________________________ -->

            <div class="col-md-6">

                <div class="form-group">
                    <label for="nombrel" name="Nombre_razon">Label:</label>
                    <input type="text" class="form-control" id="id1">
                </div>

                <!--_____________________________________________-->

                <div class="form-group">
                    <label for="nombre2" name="Cuit">Label:</label>
                    <input type="text" class="form-control" id="id2">
                </div>
                <!--_____________________________________________-->

                <div class="form-group">
                    <label for="Zonag" name="Zona">Label:</label>
                    <select class="form-control select2 select2-hidden-accesible" id="Zonag">
                        <option value="" disabled selected>-Seleccione opcion-</option>
                        <?php
                        // foreach ($Zonag as $i) {
                        //     echo '<option>'.$i->nombre.'</option>';
                        // }
                        // ?>
                    </select>
                </div>
                <!--_____________________________________________-->


                <div class="form-group">
                    <label for="TipoG" name="Tipo">Label:</label>
                    <select class="form-control select2 select2-hidden-accesible" id="TipoG">
                        <option value="" disabled selected>-Seleccione opcion-</option>
                        <?php
                        // foreach ($TipoG as $i) {
                        //     echo '<option>'.$i->nombre.'</option>';
                        // }
                        // ?>
                    </select>
                </div>
            </div>
            <!--_____________________________________________-->

            <div class="col-md-6">
                <div class="form-group">
                    <label for="Domicilio" name="Domicilio">Label:</label>
                    <input type="text" class="form-control" id="Domicilio">
                </div>
                <!--_____________________________________________-->

                <div class="form-group">
                    <label for="Dpto" name="Departamento">label:</label>
                    <select class="form-control select2 select2-hidden-accesible" id="Dpto">
                        <option value="" disabled selected>-Seleccione opcion-</option>
                        <?php
                        // foreach ($ as $i) {
                        //     echo '<option>'.$i->nombre.'</option>';
                        // }
                        // ?>
                    </select>
                </div>
                <!--_____________________________________________-->

                <div class="form-group">
                    <label for="Numero de registro" name="Numero_registro">Label:</label>
                    <input type="text" class="form-control" id="Numero de registro">
                </div>
                <!--_____________________________________________-->

                <div class="form-group">
                    <label for="Tipo de residuos" name="Tipo_Residuo">Label:</label>
                    <input type="text" class="form-control" id="Tipo de residuos">
                </div>
                <!--_____________________________________________-->

            </div>


        </form>


        <!-- /// ----------------------------------- FIN FORMULARIO ----------------------------------- /// -->


        <!-- ____________________________ GUARDAR ____________________________ -->


        <!-- __________SEPARADOR________ -->

        <div class="col-md-12">
            <hr>
        </div>

        <!-- __________SEPARADOR________ -->



        <div class="col-md-12">
            <button type="button" class="btn-sm btn-primary pull-right" onclick="clicknombre()">Aceptar</button>
        </div>

        <!-- ____________________________ GUARDAR ____________________________ -->

    </div>
</div>
</div>


<button type="button" title="Editar" class="btn btn-primary btn-circle btnEditar" data-toggle="modal" data-target="#modalEdit" id="btnEditar"><span class="glyphicon glyphicon-pencil" aria-hidden="true"></span></button>

<!--//--------------------------SCRIPT------------------------------------//-->


<script>
function agregarDato() {
    console.log("entro a agregar datos");
    $('#formGeneradores').on('submit', function(e) {

        e.preventDefault();
        var me = $(this);
        if (me.data('requestRunning')) {
            return;
        }
        me.data('requestRunning', true);

        datos = $('#formGeneradores').serialize();
        console.log(datos);
        //--------------------------------------------------------------


        $.ajax({
            type: "POST",
            data: datos,
            url: "ajax/Registrargenerador/guardarDato",
            success: function(r) {
                if (r == "ok") {
                    //console.log(datos);
                    $('#formGeneradores')[0].reset();
                    alertify.success("Agregado con exito");
                } else {
                    console.log(r);
                    $('#formGeneradores')[0].reset();
                    alertify.error("error al agregar");
                }
            },
            complete: function() {
                me.data('requestRunning', false);
            }
        });

    });

}
</script>



<!-- ***************************** Script Bootstrap Validacion. *****************************-->

<script>
$('#formGeneradores').bootstrapValidator({
    message: 'This value is not valid',
    /*feedbackIcons: {
        valid: 'glyphicon glyphicon-ok',
        invalid: 'glyphicon glyphicon-remove',
        validating: 'glyphicon glyphicon-refresh'
    },*/
    //excluded: ':disabled',
    fields: {
        Nombre_razon: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        },

        Cuit: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /^(0|[1-9][0-9]*)$/,
                    message: 'la entrada debe ser un numero entero'
                }
            }
        },

        Zona: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                }
            }
        },

        Rubro: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        },

        Tipo: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                }
            }
        },

        Domicilio: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        },

        Departamento: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                }
            }
        },

        Numero_registro: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /^(0|[1-9][0-9]*)$/,
                    message: 'la entrada debe ser un numero entero'
                }
            }
        },

        Tipo_Residuo: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        }
    }
}).on('success.form.bv', function(e) {
    e.preventDefault();
    guardar();
});
</script>


<!---//////////////////////////////////////--- FORMULARIO 1 ---///////////////////////////////////////////////////////----->

<!---//////////////////////////////////////--- FORMULARIO MIXTO ---///////////////////////////////////////////////////////----->


<div class="box box-primary">

    <!--____________________ BOX HEADER _________________________-->

    <div class="box-header with-border">
        <div class="box-tittle">
            <h3>FORMULARIO MIXTO</h3>
        </div>
    </div>

    <!--__________________ BOX BODY __________________________-->

    <div class="box-body">

        <!-- /// ----------------------------------- FORMULARIO ----------------------------------- /// -->

        <form class="formNombre1" id="IDnombre">

            <!-- ____________________________ GRUPO 1 ____________________________ -->

            <div class="col-md-12">


                <div class="col-md-6">
                    <div class="form-group">
                        <label for="nombrel" name="Nombre_razon">Label:</label>
                        <input type="text" class="form-control" id="id1">
                    </div>
                </div>

                <!--_____________________________________________-->

                <div class="col-md-6">
                    <div class="form-group">
                        <label for="nombre2" name="Cuit">Label:</label>
                        <input type="text" class="form-control" id="id2">
                    </div>
                </div>
                <!--_____________________________________________-->

                <div class="col-md-6">
                    <div class="form-group">
                        <label for="Zonag" name="Zona">Label:</label>
                        <select class="form-control select2 select2-hidden-accesible" id="Zonag">
                            <option value="" disabled selected>-Seleccione opcion-</option>
                            <?php
                        foreach ($Zonag as $i) {
                            echo '<option>'.$i->nombre.'</option>';
                        }
                        ?>
                        </select>
                    </div>
                </div>
                <!--_____________________________________________-->

                <div class="col-md-6">
                    <div class="form-group">
                        <label for="TipoG" name="Tipo">Label:</label>
                        <select class="form-control select2 select2-hidden-accesible" id="TipoG">
                            <option value="" disabled selected>-Seleccione opcion-</option>
                            <?php
                        foreach ($TipoG as $i) {
                            echo '<option>'.$i->nombre.'</option>';
                        }
                        ?>
                        </select>
                    </div>
                </div>
            </div>

            <!-- ____________________________ GRUPO 1 ____________________________ -->

            

            

            <!-- ____________________________ GRUPO 2 ____________________________ -->

            <div class="col-md-12">

                <div class="col-md-12">
                    <hr>
                </div>


                <div class="form-group">
                    <div class="col-md-4">
                        <label for="Domicilio" name="Domicilio">Label:</label>
                        <input type="text" class="form-control" id="Domicilio">
                    </div>
                </div>
                <!--_____________________________________________-->


                <div class="form-group">
                    <div class="col-md-4">
                        <label for="Dpto" name="Departamento">label:</label>
                        <select class="form-control select2 select2-hidden-accesible" id="Dpto">
                            <option value="" disabled selected>-Seleccione opcion-</option>
                            <?php
                        foreach ($Dpto as $i) {
                            echo '<option>'.$i->nombre.'</option>';
                        }
                        ?>
                        </select>
                    </div>
                </div>

                <!--_____________________________________________-->


                <div class="form-group">
                    <div class="col-md-4">
                        <label for="Numero de registro" name="Numero_registro">Label:</label>
                        <input type="text" class="form-control" id="Numero de registro">
                    </div>
                </div>
                <!--_____________________________________________-->


            </div>

            <!-- ____________________________ GRUPO 2 ____________________________ -->


           

            <!-- ____________________________ GRUPO 3 ____________________________ -->

            <div class="col-md-12">

            <div class="col-md-12"><hr></div>


                <div class="col-md-6">
                    <div class="form-group">
                        <label for="nombrel" name="Nombre_razon">Label:</label>
                        <input type="text" class="form-control" id="id1">
                    </div>
                </div>

                <!--_____________________________________________-->

                <div class="col-md-6">
                    <div class="form-group">
                        <label for="nombre2" name="Cuit">Label:</label>
                        <input type="text" class="form-control" id="id2">
                    </div>
                </div>
                <!--_____________________________________________-->

                <div class="col-md-6">
                    <div class="form-group">
                        <label for="Zonag" name="Zona">Label:</label>
                        <select class="form-control select2 select2-hidden-accesible" id="Zonag">
                            <option value="" disabled selected>-Seleccione opcion-</option>
                            <?php
                        foreach ($Zonag as $i) {
                            echo '<option>'.$i->nombre.'</option>';
                        }
                        ?>
                        </select>
                    </div>
                </div>
                <!--_____________________________________________-->

                <div class="col-md-6">
                    <div class="form-group">
                        <label for="TipoG" name="Tipo">Label:</label>
                        <select class="form-control select2 select2-hidden-accesible" id="TipoG">
                            <option value="" disabled selected>-Seleccione opcion-</option>
                            <?php
                        foreach ($TipoG as $i) {
                            echo '<option>'.$i->nombre.'</option>';
                        }
                        ?>
                        </select>
                    </div>
                </div>
            </div>



        </form>


        <!-- /// ----------------------------------- FIN FORMULARIO ----------------------------------- /// -->


        <!-- ____________________________ GUARDAR ____________________________ -->


        <!-- __________SEPARADOR________ -->

        <div class="col-md-12">
            <hr>
        </div>

        <!-- __________SEPARADOR________ -->



        <div class="col-md-12">
            <button type="button" class="btn-sm btn-primary pull-right" onclick="clicknombre()">Aceptar</button>
        </div>

        <!-- ____________________________ GUARDAR ____________________________ -->

    </div>
</div>
</div>

<!--//--------------------------SCRIPT------------------------------------//-->


<script>
function agregarDato() {
    console.log("entro a agregar datos");
    $('#formGeneradores').on('submit', function(e) {

        e.preventDefault();
        var me = $(this);
        if (me.data('requestRunning')) {
            return;
        }
        me.data('requestRunning', true);

        datos = $('#formGeneradores').serialize();
        console.log(datos);
        //--------------------------------------------------------------


        $.ajax({
            type: "POST",
            data: datos,
            url: "ajax/Registrargenerador/guardarDato",
            success: function(r) {
                if (r == "ok") {
                    //console.log(datos);
                    $('#formGeneradores')[0].reset();
                    alertify.success("Agregado con exito");
                } else {
                    console.log(r);
                    $('#formGeneradores')[0].reset();
                    alertify.error("error al agregar");
                }
            },
            complete: function() {
                me.data('requestRunning', false);
            }
        });
    });
}
</script>



<!-- ***************************** Script Bootstrap Validacion. *****************************-->

<script>
$('#formGeneradores').bootstrapValidator({
    message: 'This value is not valid',
    /*feedbackIcons: {
        valid: 'glyphicon glyphicon-ok',
        invalid: 'glyphicon glyphicon-remove',
        validating: 'glyphicon glyphicon-refresh'
    },*/
    //excluded: ':disabled',
    fields: {
        Nombre_razon: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        },

        Cuit: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /^(0|[1-9][0-9]*)$/,
                    message: 'la entrada debe ser un numero entero'
                }
            }
        },

        Zona: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                }
            }
        },

        Rubro: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        },

        Tipo: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                }
            }
        },

        Domicilio: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        },

        Departamento: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                }
            }
        },

        Numero_registro: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /^(0|[1-9][0-9]*)$/,
                    message: 'la entrada debe ser un numero entero'
                }
            }
        },

        Tipo_Residuo: {
            message: 'la entrada no es valida',
            validators: {
                notEmpty: {
                    message: 'la entrada no puede ser vacia'
                },
                regexp: {
                    regexp: /[A-Za-z]/,
                    message: 'la entrada no debe ser un numero entero'
                }
            }
        }
    }
}).on('success.form.bv', function(e) {
    e.preventDefault();
    guardar();
});
</script>


<!---//////////////////////////////////////--- FORMULARIO MIXTO ---///////////////////////////////////////////////////////----->


<!---//////////////////////////////////////---FORMULARIO 3 COLUMNAS---///////////////////////////////////////////////////////----->


<div class="box box-primary">

    <div class="box-header with-border">
        <div class="box-tittle">
            <h3>FORMULARIO 3 COLUMNAS </h3>
        </div>
    </div>


    <div class="box-body">

        <!-- /// ----------------------------------- FORMULARIO ----------------------------------- /// -->



        <!-- ____________________________ GRUPO 1 ____________________________ -->

        <div class="col-md-12">

            <div class="form-group">

                <!-- ________________________________________________________ -->

                <div class="col-md-4 col-md-6 mb-4 mb-lg-0">
                    <div class="form-group">
                        <label for="nro" class="form-label">Input:</label>
                        <input type="text" name="text" id="nro" min="0" class="form-control" required>
                    </div>
                </div>

                <!-- ________________________________________________________ -->


                <div class="col-md-4 col-md-6 mb-4 mb-lg-0">
                    <label for="zona" class="form-label">select:</label>
                    <select class="form-control select2 select2-hidden-accesible" id="zona" name="zona" required>
                        <option value="" disabled selected>-Seleccione opcion-</option>
                        <?php
                                          foreach ($lista as $i) {
                                              echo '<option>'.$i->nombre.'</option>';
                                          }
                                          ?>
                    </select>

                </div>

                <!-- ________________________________________________________ -->

                <div class="col-md-4 col-md-6 mb-4 mb-lg-0">
                    <label for="zona" class="form-label">select:</label>
                    <select class="form-control select2 select2-hidden-accesible" id="zona" name="zona" required>
                        <option value="" disabled selected>-Seleccione opcion-</option>
                        <?php
                                          foreach ($lista as $i) {
                                              echo '<option>'.$i->nombre.'</option>';
                                          }
                                          ?>
                    </select>

                </div>


                <!-- ________________________________________________________ -->

            </div>

        </div>

        <!-- ____________________________ SEPARADOR ____________________________ -->

        <div class="col-md-12">
            <br>
        </div>




        <!-- ____________________________ GRUPO 2 ____________________________ -->

        <div class="col-md-12">

            <div class="form-group">

                <div class="col-md-4">

                    <label style="margin-left:10px" for="">Input:</label>
                    <div class="col-md-12  input-group" style="margin-left:15px">

                        <input list="listanombre" id="idnombre" placeholder="Seleccione opcion" class="form-control"
                            autocomplete="off">

                        <datalist id="iddatalist">
                            <?php foreach($lista as $fila)
                            {
                                echo  "<option data-json='".json_encode($fila)."' value='".$fila->nombre."'>";
                            }
                                ?>
                        </datalist>


                        <span class="input-group-btn">
                            <button class='btn btn-primary' data-toggle="modal" data-target="#modal_nombre">
                                <i class="glyphicon glyphicon-search"></i></button>
                        </span>

                    </div>
                </div>


                <!-- ____________________________ ROW____________________________ -->

                <div class="col-md-4  col-sm-6 mb-4 mb-lg-0">
                    <label for="" style="margin-left:10px">Input:</label>
                    <div class="col-md-12  input-group" style="margin-left:15px">
                        <input list="listanombre" id="idnombre" class="form-control" autocomplete="off"
                            placeholder="Seleccione opcion">
                        <datalist id="datalist">


                        </datalist>
                        <span class="input-group-btn">
                            <button class='btn btn-primary' data-toggle="modal" data-target="#modal_nombre">
                                <i class="glyphicon glyphicon-search"></i></button>
                        </span>
                    </div>
                </div>


                <div class="col-md-4  col-sm-6 mb-4 mb-lg-0">
                    <label for="" style="margin-left:10px">Input:</label>
                    <div class="col-md-12  input-group" style="margin-left:15px">
                        <input list="listanombre" id="idnombre" class="form-control" autocomplete="off"
                            placeholder="Seleccione opcion">
                        <datalist id="iddatalist">


                        </datalist>
                        <span class="input-group-btn">
                            <button class='btn btn-primary' data-toggle="modal" data-target="#modal_nombre">
                                <i class="glyphicon glyphicon-search"></i></button>
                        </span>
                    </div>
                </div>









            </div>


            <!-- ____________________________ GUARDAR ____________________________ -->


            <div class="col-md-12">
                <hr>
            </div>


            <div class="col-md-12">


                <button type="button" class="btn-sm btn-primary pull-right" onclick="clicknombre()">Aceptar</button>


            </div>

            <!-- ____________________________ GUARDAR ____________________________ -->


            </form>

        </div>


        <!-- /// ----------------------------------- FIN FORMULARIO ----------------------------------- /// -->


    </div><!-- /.box-body -->

</div>




<!---////////////////////////////////////////---DATA TABLES 1---/////////////////////////////////////////////////////----->
<div class="box box-primary">
    <div class="box-header with-border">
        <div class="box-tittle">
            <h3>DATATABLES 1</h3>
        </div>
    </div>

    <div class="box-body table-scroll">
        <table id="example2" class="table table-bordered table-hover table-responsive">
            <thead>
                <tr>
                    <th>Rendering engine</th>
                    <th>Browser</th>
                    <th>Platform(s)</th>
                    <th>Engine version</th>
                    <th>CSS grade</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 4.0
                    </td>
                    <td>Win 95+</td>
                    <td> 4</td>
                    <td>X</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 5.0
                    </td>
                    <td>Win 95+</td>
                    <td>5</td>
                    <td>C</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 5.5
                    </td>
                    <td>Win 95+</td>
                    <td>5.5</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 6
                    </td>
                    <td>Win 98+</td>
                    <td>6</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet Explorer 7</td>
                    <td>Win XP SP2+</td>
                    <td>7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>AOL browser (AOL desktop)</td>
                    <td>Win XP</td>
                    <td>6</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 1.0</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 1.5</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 2.0</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 3.0</td>
                    <td>Win 2k+ / OSX.3+</td>
                    <td>1.9</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Camino 1.0</td>
                    <td>OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Camino 1.5</td>
                    <td>OSX.3+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Netscape 7.2</td>
                    <td>Win 95+ / Mac OS 8.6-9.2</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Netscape Browser 8</td>
                    <td>Win 98SE+</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Netscape Navigator 9</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.0</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.1</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.2</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.2</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.3</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.3</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.4</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.4</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.5</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.5</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.6</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.6</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.7</td>
                    <td>Win 98+ / OSX.1+</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.8</td>
                    <td>Win 98+ / OSX.1+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Seamonkey 1.1</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Epiphany 2.20</td>
                    <td>Gnome</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 1.2</td>
                    <td>OSX.3</td>
                    <td>125.5</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 1.3</td>
                    <td>OSX.3</td>
                    <td>312.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 2.0</td>
                    <td>OSX.4+</td>
                    <td>419.3</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 3.0</td>
                    <td>OSX.4+</td>
                    <td>522.1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>OmniWeb 5.5</td>
                    <td>OSX.4+</td>
                    <td>420</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>iPod Touch / iPhone</td>
                    <td>iPod</td>
                    <td>420.1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>S60</td>
                    <td>S60</td>
                    <td>413</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.0</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.0</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 9.0</td>
                    <td>Win 95+ / OSX.3+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>

                </tfoot>
        </table>
    </div>

</div>





<!---//////////////////////////////////////---DATA TABLES 1---///////////////////////////////////////////////////////----->


<!---///////////////////////////////---DATA TABLES 2---//////////////////////////////////////////////////////////////----->
<div class="box box-primary">
    <div class="box-header with-border">
        <div class="box-tittle">
            <h3>DATATABLES 2 tuninig</h3>
        </div>
    </div>

    <div class="box-body table-scroll table-responsive">
        <table id="example1" class="table table-bordered table-hover">
            <thead>
                <tr>
                    <th>A</th>
                    <th>Browser</th>
                    <th>Platform(s)</th>
                    <th>Engine version</th>
                    <th>CSS grade</th>                    
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 4.0
                    </td>
                    <td>Win 95+</td>
                    <td> 4</td>
                    <td>X</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 5.0
                    </td>
                    <td>Win 95+</td>
                    <td>5</td>
                    <td>C</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 5.5
                    </td>
                    <td>Win 95+</td>
                    <td>5.5</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet
                        Explorer 6
                    </td>
                    <td>Win 98+</td>
                    <td>6</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>Internet Explorer 7</td>
                    <td>Win XP SP2+</td>
                    <td>7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Trident</td>
                    <td>AOL browser (AOL desktop)</td>
                    <td>Win XP</td>
                    <td>6</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 1.0</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 1.5</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 2.0</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Firefox 3.0</td>
                    <td>Win 2k+ / OSX.3+</td>
                    <td>1.9</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Camino 1.0</td>
                    <td>OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Camino 1.5</td>
                    <td>OSX.3+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Netscape 7.2</td>
                    <td>Win 95+ / Mac OS 8.6-9.2</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Netscape Browser 8</td>
                    <td>Win 98SE+</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Netscape Navigator 9</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.0</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.1</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.2</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.2</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.3</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.3</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.4</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.4</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.5</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.5</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.6</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>1.6</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.7</td>
                    <td>Win 98+ / OSX.1+</td>
                    <td>1.7</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Mozilla 1.8</td>
                    <td>Win 98+ / OSX.1+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Seamonkey 1.1</td>
                    <td>Win 98+ / OSX.2+</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Gecko</td>
                    <td>Epiphany 2.20</td>
                    <td>Gnome</td>
                    <td>1.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 1.2</td>
                    <td>OSX.3</td>
                    <td>125.5</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 1.3</td>
                    <td>OSX.3</td>
                    <td>312.8</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 2.0</td>
                    <td>OSX.4+</td>
                    <td>419.3</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>Safari 3.0</td>
                    <td>OSX.4+</td>
                    <td>522.1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>OmniWeb 5.5</td>
                    <td>OSX.4+</td>
                    <td>420</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>iPod Touch / iPhone</td>
                    <td>iPod</td>
                    <td>420.1</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>S60</td>
                    <td>S60</td>
                    <td>413</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.0</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.0</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 9.0</td>
                    <td>Win 95+ / OSX.3+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>S60</td>
                    <td>S60</td>
                    <td>413</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.0</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.0</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 9.0</td>
                    <td>Win 95+ / OSX.3+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Webkit</td>
                    <td>S60</td>
                    <td>S60</td>
                    <td>413</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.0</td>
                    <td>Win 95+ / OSX.1+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 7.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.0</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 8.5</td>
                    <td>Win 95+ / OSX.2+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>
                <tr>
                    <td>Presto</td>
                    <td>Opera 9.0</td>
                    <td>Win 95+ / OSX.3+</td>
                    <td>-</td>
                    <td>A</td>
                </tr>


                </tfoot>
        </table>
    </div>

</div>





<!-- Script Data-Tables-->




<!---//////////////////////////////////////---DATA TABLES 2---///////////////////////////////////////////////////////----->













<!---//////////////////////////////////////---DATA TABLES SCRIPT---///////////////////////////////////////////////////////----->
<!-- Script Data-Tables-->
<script>
$(function() {

    $('#example2').DataTable({
        'paging': true,
        'lengthChange': true,
        'searching': true,
        'ordering': true,
        'info': true,
        'autoWidth': true,
        'autoFill': true,
        'buttons': true,
        'fixedHeader': true,
        dom: 'Bfrtip',
        buttons: [
            'excel', 'pdf', 'print'
        ]
    })
})




$('#example1').DataTable({
    'paging': true,
    'lengthChange': true,
    'searching': true,
    'ordering': true,
    'info': true,
    'autoWidth': true,
    'autoFill': true,
    'buttons': true,
    'fixedHeader': true,
    

});
</script>

<!-- Script Data-Tables-->

<!-- <script>
a=jQuery.noConflict();
a(document).ready(function(){
a("button").click(function(){
a("p").text("jQuery continua funcionando!");
});
});
</script> -->

<!---//////////////////////////////////////---DATA TABLES SCRIPT---///////////////////////////////////////////////////////----->







<!---//////////////////////////////////////---DATA TABLES SCRIPT---///////////////////////////////////////////////////////----->



<div class="modal fade bs-example-modal-lg" id="modalEdit" tabindex="-1" role="dialog" aria-labelledby="myLargeModalLabel">
    <div class="modal-dialog modal-lg" role="document">
      <div class="modal-content">
        <div class="modal-header bg-blue">
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
            </button>
            <h5 class="modal-title" id="exampleModalLabel">Circuitos</h5>
        </div>

				<div class="modal-body ">
					<div class="form-horizontal">

						<div class="col-sm-6">
							<!--_____________ CODIGO _____________-->
								<div class="form-group">																
									<label for="codigo" name="codigo" class="col-sm-4 control-label">Código:</label>
									<div class="col-sm-8">
										<input type="text" class="form-control habilitar" name="codigo" id="codigo_edit">	
									</div>
								</div> 
							<!--___________________________-->
				
							<!--_____________ VEHICULO _____________-->
								<div class="form-group">																
									<label for="vehiculo" name="vehiculo" class="col-sm-4 control-label">Vehiculo:</label>
									<div class="col-sm-8">
										<input type="text" class="form-control habilitar" id="vehiculo_edit" name="vehiculo" > 
									</div>
									<input type="text" class="form-control habilitar hidden" id="vehiculo_edit" name="vehi_id"> 
								</div>   
							<!--__________________________-->	 
						
							<!--_____________ CHOFER _____________-->
								<div class="form-group">																
									<label for="Chofer" name="Chofer" class="col-sm-4 control-label">Chofer:</label>
									<div class="col-sm-8">
										<input type="text" class="form-control habilitar" id="Chofer">
									</div>	
								</div>
							<!--__________________________-->
						</div>

						<div class="col-sm-6">
							<!--_____________ TIPO RESIDUOS _____________-->
								<div class="form-group">															
									<label for="tipoResiduos" name="tipoResiduos" class="col-sm-4 control-label">Tipo de residuo:</label>
									<div class="col-sm-8">
										<input type="text" class="form-control habilitar" id="tipoResiduos"> 
									</div>	
								</div>
							<!--__________________________-->												
									
							<!--_____________ DESCRIPCION _____________-->                 
								<div class="form-group">
										<label for="Descripcion" class="col-sm-4 control-label">Descripcion:</label>
										<div class="col-sm-8">
											<input type="text" class="form-control habilitar" id="tipoResiduos"> 
										</div>
								</div>
							<!--__________________________-->								
						</div>

						<div class="col-sm-12">

							<!--_____________ IMAGEN _____________-->
							<div class="form-group pull-left">
								<label for="Descripcion" class="col-sm-4 control-label">Imágen:</label>
								<div class="col-sm-8">
									<input type="file" class="habilitar" id="tipoResiduos"> 
								</div>
							</div> 
							<!--__________________________-->	
						</div>

					</div>

					<!--_____________ SECCION P. CRITICOS _____________-->							
					<div class="row">  							

						<div class="col-sm-6">
							<!--_____________ Nombre _____________-->
								<div class="form-group">															
									<label for="tipoResiduos" name="tipoResiduos" class="col-sm-4 control-label">Nombre:</label>
									<div class="col-sm-8">
										<input type="text" class="form-control habilitar" id="tipoResiduos"> 
									</div>	
								</div>
							<!--__________________________-->		
						</div>	
						<div class="col-sm-6">
							<!--_____________ Nombre _____________-->
								<div class="form-group">															
									<label for="tipoResiduos" name="tipoResiduos" class="col-sm-4 control-label">Descripcion:</label>
									<div class="col-sm-8">
										<input type="text" class="form-control habilitar" id="tipoResiduos"> 
									</div>	
								</div>
							<!--__________________________-->		
						</div>		

						<div class="col-md-12">                                          
						
							<table id="tabla_puntos_criticos" class="table table-bordered table-striped">
									<thead class="thead-dark" bgcolor="#eeeeee">																										
											<th>Nombre</th>
											<th>Descripcion</th>
											<th>Ubicacion</th>								
								</thead>
							
								<tbody>
										
								</tbody>
							</table>                                    
																										 
						</div>   
									
					</div>
					<!--____________SECCION P. CRITICOS______________-->


				</div>			

				<div class="modal-footer">
					<div class="form-group text-right">
							<button type="submit" class="btn btn-primary" data-dismiss="modal" id="btnsave">Guardar</button>
							<button type="submit" class="btn btn-default" id="" data-dismiss="modal">Cerrar</button>
					</div>
				</div>

      </div>
    </div>
</div>




<ul class="sidebar-menu" data-widget="tree">
        <li class="header">MAIN NAVIGATION</li>
        
        <li class="treeview">
          <a href="#">
            <i class="fa fa-share"></i> <span>Multilevel</span>
            <span class="pull-right-container">
              <i class="fa fa-angle-left pull-right"></i>
            </span>
          </a>
          <ul class="treeview-menu">
            <li><a href="#"><i class="fa fa-circle-o"></i> Level One</a></li>
            <li class="treeview">
              <a href="#"><i class="fa fa-circle-o"></i> Level One
                <span class="pull-right-container">
                  <i class="fa fa-angle-left pull-right"></i>
                </span>
              </a>
              <ul class="treeview-menu">
                <li><a href="#"><i class="fa fa-circle-o"></i> Level Two</a></li>
                <li class="treeview">
                  <a href="#"><i class="fa fa-circle-o"></i> Level Two
                    <span class="pull-right-container">
                      <i class="fa fa-angle-left pull-right"></i>
                    </span>
                  </a>
                  <ul class="treeview-menu">
                    <li><a href="#"><i class="fa fa-circle-o"></i> Level Three</a></li>
                    <li><a href="#"><i class="fa fa-circle-o"></i> Level Three</a></li>
                  </ul>
                </li>
              </ul>
            </li>
            <li><a href="#"><i class="fa fa-circle-o"></i> Level One</a></li>
          </ul>
        </li>
       
</ul>


















