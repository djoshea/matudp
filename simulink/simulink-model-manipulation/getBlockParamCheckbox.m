function isChecked = getBlockParamCheckbox(block, param)

isChecked = strcmp(getBlockParamEval(block, param), 'on');