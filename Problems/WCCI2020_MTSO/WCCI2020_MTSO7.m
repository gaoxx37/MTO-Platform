classdef WCCI2020_MTSO7 < Problem

    properties
    end

    methods
        function parameter = getParameter(obj)
            parameter = obj.getRunParameter();
        end

        function obj = setParameter(obj, parameter_cell)
            obj.setRunParameter(parameter_cell(1:3));
        end

        function Tasks = getTasks(obj)
            Tasks = benchmark_WCCI2020_MTSO(7);
        end

    end

end