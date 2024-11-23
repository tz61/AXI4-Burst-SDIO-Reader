# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "C_AXI_TARGET_SLAVE_BASE_ADDR" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXI_BURST_LEN" -parent ${Page_0} -widget comboBox
  ipgui::add_param $IPINST -name "C_AXI_ID_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXI_ADDR_WIDTH" -parent ${Page_0}
  ipgui::add_param $IPINST -name "C_AXI_DATA_WIDTH" -parent ${Page_0} -widget comboBox

  set SDIO_BURST_SECTOR_START [ipgui::add_param $IPINST -name "SDIO_BURST_SECTOR_START"]
  set_property tooltip {Start from first 0 to  511.9995117MiB} ${SDIO_BURST_SECTOR_START}
  set SDIO_BURST_SECTOR_COUNT [ipgui::add_param $IPINST -name "SDIO_BURST_SECTOR_COUNT"]
  set_property tooltip {Read sector count, max ability:511.9995117 MiB(1048575)} ${SDIO_BURST_SECTOR_COUNT}

}

proc update_PARAM_VALUE.SDIO_BURST_SECTOR_COUNT { PARAM_VALUE.SDIO_BURST_SECTOR_COUNT } {
	# Procedure called to update SDIO_BURST_SECTOR_COUNT when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SDIO_BURST_SECTOR_COUNT { PARAM_VALUE.SDIO_BURST_SECTOR_COUNT } {
	# Procedure called to validate SDIO_BURST_SECTOR_COUNT
	return true
}

proc update_PARAM_VALUE.SDIO_BURST_SECTOR_START { PARAM_VALUE.SDIO_BURST_SECTOR_START } {
	# Procedure called to update SDIO_BURST_SECTOR_START when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.SDIO_BURST_SECTOR_START { PARAM_VALUE.SDIO_BURST_SECTOR_START } {
	# Procedure called to validate SDIO_BURST_SECTOR_START
	return true
}

proc update_PARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to update C_AXI_TARGET_SLAVE_BASE_ADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR { PARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to validate C_AXI_TARGET_SLAVE_BASE_ADDR
	return true
}

proc update_PARAM_VALUE.C_AXI_BURST_LEN { PARAM_VALUE.C_AXI_BURST_LEN } {
	# Procedure called to update C_AXI_BURST_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_BURST_LEN { PARAM_VALUE.C_AXI_BURST_LEN } {
	# Procedure called to validate C_AXI_BURST_LEN
	return true
}

proc update_PARAM_VALUE.C_AXI_ID_WIDTH { PARAM_VALUE.C_AXI_ID_WIDTH } {
	# Procedure called to update C_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_ID_WIDTH { PARAM_VALUE.C_AXI_ID_WIDTH } {
	# Procedure called to validate C_AXI_ID_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXI_ADDR_WIDTH { PARAM_VALUE.C_AXI_ADDR_WIDTH } {
	# Procedure called to update C_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_ADDR_WIDTH { PARAM_VALUE.C_AXI_ADDR_WIDTH } {
	# Procedure called to validate C_AXI_ADDR_WIDTH
	return true
}

proc update_PARAM_VALUE.C_AXI_DATA_WIDTH { PARAM_VALUE.C_AXI_DATA_WIDTH } {
	# Procedure called to update C_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_AXI_DATA_WIDTH { PARAM_VALUE.C_AXI_DATA_WIDTH } {
	# Procedure called to validate C_AXI_DATA_WIDTH
	return true
}


proc update_MODELPARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR { MODELPARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR PARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR}] ${MODELPARAM_VALUE.C_AXI_TARGET_SLAVE_BASE_ADDR}
}

proc update_MODELPARAM_VALUE.C_AXI_BURST_LEN { MODELPARAM_VALUE.C_AXI_BURST_LEN PARAM_VALUE.C_AXI_BURST_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_BURST_LEN}] ${MODELPARAM_VALUE.C_AXI_BURST_LEN}
}

proc update_MODELPARAM_VALUE.C_AXI_ID_WIDTH { MODELPARAM_VALUE.C_AXI_ID_WIDTH PARAM_VALUE.C_AXI_ID_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_AXI_ID_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXI_ADDR_WIDTH { MODELPARAM_VALUE.C_AXI_ADDR_WIDTH PARAM_VALUE.C_AXI_ADDR_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_AXI_DATA_WIDTH { MODELPARAM_VALUE.C_AXI_DATA_WIDTH PARAM_VALUE.C_AXI_DATA_WIDTH } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.C_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.SDIO_BURST_SECTOR_START { MODELPARAM_VALUE.SDIO_BURST_SECTOR_START PARAM_VALUE.SDIO_BURST_SECTOR_START } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SDIO_BURST_SECTOR_START}] ${MODELPARAM_VALUE.SDIO_BURST_SECTOR_START}
}

proc update_MODELPARAM_VALUE.SDIO_BURST_SECTOR_COUNT { MODELPARAM_VALUE.SDIO_BURST_SECTOR_COUNT PARAM_VALUE.SDIO_BURST_SECTOR_COUNT } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.SDIO_BURST_SECTOR_COUNT}] ${MODELPARAM_VALUE.SDIO_BURST_SECTOR_COUNT}
}

