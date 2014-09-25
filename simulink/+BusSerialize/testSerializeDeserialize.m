function testSerializeDeserialize()

import BusSerialize.writeSerializeBusCode;
import BusSerialize.writeDerializeBusCode;

%% create buses and author serialization code

testSerializedParams_Initialize;

writeSerializeBusCode('TestBus');
writeSerializeBusCode('TestBusInner');
writeSerializeBusCode('TestBusOuter');

writeDeserializeBusCode('TestBus');
writeDeserializeBusCode('TestBusInner');
writeDeserializeBusCode('TestBusOuter');

%% test serialization

TestBusVal = prepStruct(TestBusVal);
TestBusOuterVal = prepStruct(TestBusOuterVal);
TestBusInnerVal = prepStruct(TestBusInnerVal);

[s, valid] = testSerializedParamsLib.serializeBus_TestBus(TestBusVal);
if ~valid
    error('Error serializing');
end
[ds, valid] = testSerializedParamsLib.deserializeBus_TestBus(s);

if valid && isequal(ds, TestBusVal)
    fprintf('TestBus: Pass\n');
else
    fprintf('TestBus: Fail\n');
end

[s, valid] = testSerializedParamsLib.serializeBus_TestBusInner(TestBusInnerVal);
if ~valid
    error('Error serializing');
end

[ds, valid] = testSerializedParamsLib.deserializeBus_TestBusInner(s);

if valid && isequal(ds, TestBusInnerVal)
    fprintf('TestBusInner: Pass\n');
else
    fprintf('TestBusInner: Fail\n');
end

[s, valid] = testSerializedParamsLib.serializeBus_TestBusOuter(TestBusOuterVal);
if ~valid
    error('Error serializing');
end

[ds, valid] = testSerializedParamsLib.deserializeBus_TestBusOuter(s);
if valid &&  isequal(ds, TestBusOuterVal)
    fprintf('TestBusOuter: Pass\n');
else
    fprintf('TestBusOuter: Fail\n');
end

end

function v = prepStruct(v)
    flds = fieldnames(v);
    for iV = 1:numel(v)
        for iF = 1:numel(flds)
            if isstruct(v(iV).(flds{iF}))
                v(iV).(flds{iF}) = makecol(prepStruct(v(iV).(flds{iF})));
            else
                v(iV).(flds{iF}) = convToUint8(makecol(v(iV).(flds{iF})));
            end
        end
    end
end

function v = convToUint8(v)
    if islogical(v) || ischar(v)
        v = uint8(v);
    end
end

function v = makecol(v)
    if isvector(v) && size(v, 2) > size(v, 1)
        v = v';
    end
end
        