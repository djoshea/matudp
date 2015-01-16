classdef ScreenObjectManager < handle

    properties
        sd
        objList % list of Screen objects in objList, automatically filtered to delete invalid objects

        debugLevel % only objects with .debugLevel <= this.debugLevel will be drawn
                   % i.e. set higher to include more detailed debug information
    end

    properties(Dependent)
        sortedObjList % list of Screen objects in objList, sorted by ascending zOrder
    end

    methods
        function som = ScreenObjectManager(sd)
            if nargin < 1
                error('Usage: ScreenObjectManager(ScreenDraw sd)');
            end
            som.sd = sd;
            som.objList = []; 
        end

        function add(som, sobj)
            assert(isa(sobj, 'ScreenObject'), 'Can only add objects of class ScreenObject');
            som.objList = [som.objList sobj];
        end

        function remove(som, sobj)
            som.objList = som.objList(~isequal(som.objList, sobj));
        end
            
        function flush(som)
            som.objList = [];
        end

        function list = get.objList(som)
            if isempty(som.objList)
                list = [];
            else
                % filter only the valid objects in the list
                list = som.objList(isvalid(som.objList));
                som.objList = list;
            end
        end

        function list = get.sortedObjList(som)
            if isempty(som.objList)
                list = [];
                return;
            end
            zOrderList = [som.objList.zOrder];
            [sorted sortIdx] = sort(zOrderList);

            list = som.objList(sortIdx);
        end
        
        function updateAll(som)
            list = som.objList;
            for i = 1:length(list)
                list(i).update(som, som.sd);
            end
        end

        function drawAll(som)
            % sort by z order and then draw if visible
            list = som.sortedObjList;
            if isempty(list)
                return;
            end
            list = list([list.visible]);
            for i = 1:length(list)
                list(i).draw(som.sd);
            end
        end

    end
end
