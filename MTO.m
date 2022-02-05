function mto(varargin)
    %% MTO Platform
    % GUI: 'mto;'
    % Command line: 'mto(algo_cell, prob_cell, reps, save_name);'

    addpath(genpath('./Algorithms/'));
    addpath(genpath('./Problems/'));
    addpath(genpath('./GUI/'));

    if isempty(varargin)
        % run with GUI
        MTO_GUI();
    else
        % run with command line, save data in mat file
        reps = 1;
        save_name = 'data_save';
        algo_cell = varargin{1};
        prob_cell = varargin{2};
        if length(varargin) == 3
            reps = varargin{3};
        end
        if length(varargin) == 4
            save_name = varargin{4};
        end
        MTO_commandline(algo_cell, prob_cell, reps, save_name);
    end
end
