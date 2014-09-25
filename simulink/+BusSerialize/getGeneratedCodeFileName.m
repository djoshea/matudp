function fileName = getGeneratedCodeFileName(fnName)
% returns '/codePath/fnName.m' via getCodePath()

p = BusSerialize.getGeneratedCodePath();
fileName = fullfile(p, sprintf('%s.m', fnName));

end