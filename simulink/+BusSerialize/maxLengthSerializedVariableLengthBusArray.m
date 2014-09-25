function maxLength = maxLengthSerializedVariableLengthBusArray(busName, maxElements)

% save room for the lengths offsets
arrayHeaderLen = 2 + 4*maxElements;
maxLength = arrayHeaderLen + maxElements * BusSerialize.computeMaxSerializedBusLength(busName);

end

