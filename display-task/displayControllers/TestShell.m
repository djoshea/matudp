classdef TestShell < DisplayController
% This class runs a shell which responds similarly to NetworkShell
% but is driven via manual command entry.

    methods
        function ns = TestShell(varargin)
            ns = ns@DisplayController(varargin{:});
            ns.name = 'TestShell';
        end
    end

    methods(Access=protected)
        function initialize(ns)
            ns.setTask('TestMouseTask');
        end

        function cleanup(ns)

        end

        function update(ns)
            
        end
    end

end
