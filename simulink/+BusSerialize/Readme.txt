
Buses will be serialized by looping over their signals in order. Nested buses will be flattened and serialized in place. Each signal will be serialized in the following pattern:

1 uint8 : flags
  low-bit 0: isVariable size

1 uint16 : nName : length of signal name in characters

nName char : name (without null trailing character)

1 uint16 : nUnits : length of signal units in characters

nUnits char : units string

1 uint8 : nDimensions

nDimensions uint16 : size along each dimension

1 uint8 : data type id

nData class(data) : raw data. nData determined by prod(size). class determined by data

