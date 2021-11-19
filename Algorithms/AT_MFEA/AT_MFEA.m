classdef AT_MFEA < Algorithm
    % @Article{xue2020AT-MFEA,
    %     author     = {Xue, Xiaoming and Zhang, Kai and Tan, Kay Chen and Feng, Liang and Wang, Jian and Chen, Guodong and Zhao, Xinggang and Zhang, Liming and Yao, Jun},
    %     journal    = {IEEE Transactions on Cybernetics},
    %     title      = {Affine transformation-enhanced multifactorial optimization for heterogeneous problems},
    %     year       = {2020},
    %     publisher  = {IEEE},
    % }

    properties (SetAccess = private)
        rmp = 0.3
        selection_process = 'elitist'
        p_il = 0;
        mu = 2; % index of Simulated Binary Crossover (tunable)
        mum = 5; % index of polynomial mutation
        probswap = 0.5; % probability of variable swap
    end

    methods

        function parameter = getParameter(obj)
            parameter = {'rmp: Random Mating Probability', num2str(obj.rmp), ...
                        '("elitist"/"roulette wheel"): Selection Type', obj.selection_process, ...
                        'p_il: Local Search Probability', num2str(obj.p_il), ...
                        'mu: index of Simulated Binary Crossover (tunable)', num2str(obj.mu), ...
                        'mum: index of polynomial mutation', num2str(obj.mum), ...
                        'probSwap: Variable Swap Probability', num2str(obj.probswap)};
        end

        function obj = setParameter(obj, parameter_cell)
            count = 1;
            obj.rmp = str2double(parameter_cell{count}); count = count + 1;
            obj.selection_process = parameter_cell{count}; count = count + 1;
            obj.p_il = str2double(parameter_cell{count}); count = count + 1;
            obj.mu = str2num(parameter_cell{count}); count = count + 1;
            obj.sigma = str2double(parameter_cell{count}); count = count + 1;
            obj.mum = str2num(parameter_cell{count}); count = count + 1;
            obj.probswap = str2double(parameter_cell{count}); count = count + 1;
        end

        function data = run(obj, Tasks, run_parameter_list)
            pop = run_parameter_list(1);
            gen = run_parameter_list(2);
            eva_num = run_parameter_list(3);
            rmp = obj.rmp;
            selection_process = obj.selection_process;
            p_il = obj.p_il;
            mu = obj.mu;
            mum = obj.mum;
            probswap = obj.probswap;

            tic
            no_of_tasks = length(Tasks);
            if mod(pop, no_of_tasks) ~= 0
                pop = pop + no_of_tasks - mod(pop, no_of_tasks);
            end
            if no_of_tasks <= 1
                error('At least 2 tasks required for MFEA');
            end
            D = zeros(1, no_of_tasks);
            for i = 1:no_of_tasks
                D(i) = Tasks(i).dims;
            end
            D_multitask = max(D);

            options = optimoptions(@fminunc, 'Display', 'off', 'Algorithm', 'quasi-newton', 'MaxIter', 2); % local search - optional.

            fnceval_calls = zeros(1);
            calls_per_individual = zeros(1, pop);
            bestobj = Inf(1, no_of_tasks);
            rmpval = inf(gen);

            for i = 1:pop
                population(i) = Chromosome_AT_MFEA();
                population(i) = initialize(population(i), D_multitask);
                population(i).skill_factor = 0;
            end
            for i = 1:pop
                [population(i), calls_per_individual(i)] = evaluate(population(i), Tasks, p_il, no_of_tasks, options);
            end

            fnceval_calls = fnceval_calls + sum(calls_per_individual);
            TotalEvaluations(1) = fnceval_calls;

            rmpval(1) = 0;

            factorial_cost = zeros(1, pop);
            for i = 1:no_of_tasks
                for j = 1:pop
                    factorial_cost(j) = population(j).factorial_costs(i);
                end
                [xxx, y] = sort(factorial_cost);
                population = population(y);
                for j = 1:pop
                    population(j).factorial_ranks(i) = j;
                end
                bestobj(i) = population(1).factorial_costs(i);
                EvBestFitness(i, 1) = bestobj(i);
                bestInd_data(i) = population(1);
            end
            for i = 1:pop
                [xxx, yyy] = min(population(i).factorial_ranks);
                x = find(population(i).factorial_ranks == xxx);
                equivalent_skills = length(x);
                if equivalent_skills > 1
                    population(i).skill_factor = x(1 + round((equivalent_skills - 1) * rand(1)));
                    tmp = population(i).factorial_costs(population(i).skill_factor);
                    population(i).factorial_costs(1:no_of_tasks) = inf;
                    population(i).factorial_costs(population(i).skill_factor) = tmp;
                else
                    population(i).skill_factor = yyy;
                    tmp = population(i).factorial_costs(population(i).skill_factor);
                    population(i).factorial_costs(1:no_of_tasks) = inf;
                    population(i).factorial_costs(population(i).skill_factor) = tmp;
                end
            end

            [mu_tasks, Sigma_tasks] = InitialDistribution(population, no_of_tasks);

            generation = 1;

            while generation < gen && TotalEvaluations(generation) < eva_num
                generation = generation +1;

                %Extract task specific data sets
                for i = 1:no_of_tasks
                    subpops(i).data = [];
                end

                for i = 1:pop
                    subpops(population(i).skill_factor).data = [subpops(population(i).skill_factor).data; population(i).rnvec];
                end

                RMP = rmp * ones(no_of_tasks, no_of_tasks); % Prespecified rmp

                indorder = randperm(pop);
                count = 1;
                for i = 1:pop / 2
                    p1 = indorder(i);
                    p2 = indorder(i + (pop / 2));
                    child(count) = Chromosome_AT_MFEA();
                    child(count + 1) = Chromosome_AT_MFEA();

                    tempchild1 = Chromosome_AT_MFEA();
                    tempchild2 = Chromosome_AT_MFEA();

                    rmp = RMP(population(p1).skill_factor, population(p2).skill_factor);

                    u = rand(1, D_multitask);
                    cf = zeros(1, D_multitask);
                    cf(u <= 0.5) = (2 * u(u <= 0.5)).^(1 / (mu + 1));
                    cf(u > 0.5) = (2 * (1 - u(u > 0.5))).^(-1 / (mu + 1));

                    if (population(p1).skill_factor == population(p2).skill_factor) % Intra-task crossover

                        % Crossover + Mutate
                        child(count) = crossover(child(count), population(p1), population(p2), cf);
                        child(count + 1) = crossover(child(count + 1), population(p2), population(p1), cf);
                        if rand(1) < 1
                            child(count) = mutate(child(count), child(count), D_multitask, mum);
                            child(count + 1) = mutate(child(count + 1), child(count + 1), D_multitask, mum);
                        end

                        child(count).skill_factor = population(p1).skill_factor;
                        child(count + 1).skill_factor = population(p2).skill_factor;

                        % variable swap (uniform X)
                        swap_indicator = (rand(1, D_multitask) >= probswap);
                        temp = child(count + 1).rnvec(swap_indicator);
                        child(count + 1).rnvec(swap_indicator) = child(count).rnvec(swap_indicator);
                        child(count).rnvec(swap_indicator) = temp;

                    elseif (rand(1) < rmp) % Inter-task crossover

                        % Mapping-based crossover + Mutate
                        pm1 = population(p1);
                        pm2 = population(p2);
                        pm1.rnvec = AT_Transfer(population(p1).rnvec, mu_tasks{population(p1).skill_factor}, Sigma_tasks{population(p1).skill_factor}, mu_tasks{population(p2).skill_factor}, Sigma_tasks{population(p2).skill_factor});
                        pm2.rnvec = AT_Transfer(population(p2).rnvec, mu_tasks{population(p2).skill_factor}, Sigma_tasks{population(p2).skill_factor}, mu_tasks{population(p1).skill_factor}, Sigma_tasks{population(p1).skill_factor});
                        child(count) = crossover(child(count), pm1, population(p2), cf);
                        child(count + 1) = crossover(child(count + 1), population(p1), pm2, cf);

                        if rand(1) < 1
                            child(count) = mutate(child(count), child(count), D_multitask, mum);
                            child(count + 1) = mutate(child(count + 1), child(count + 1), D_multitask, mum);
                        end

                        sf1 = 1 + round(rand(1));
                        sf2 = 1 + round(rand(1));
                        if sf1 == 1 % skill factor selection
                            child(count).skill_factor = population(p1).skill_factor;
                        else
                            child(count).skill_factor = population(p2).skill_factor;
                        end

                        if sf2 == 1
                            child(count + 1).skill_factor = population(p1).skill_factor;
                        else
                            child(count + 1).skill_factor = population(p2).skill_factor;
                        end

                    else %rand(1) > rmp

                        % Randomly pick another individual from the  same task
                        % for Crossover (SBX + uniform)  + Mutate

                        %select another unique individual p11 having the same skill factor as p1
                        sol1 = find([population.skill_factor] == population(p1).skill_factor);
                        c1 = numel(sol1);
                        idx1 = randi(c1);
                        p11 = sol1(idx1);

                        while (p11 == p1)
                            idx1 = randi(c1);
                            p11 = sol1(idx1);
                        end

                        %select another unique individual p22 having the same skill factor as p2
                        sol2 = find([population.skill_factor] == population(p2).skill_factor);
                        c2 = numel(sol2);
                        idx2 = randi(c2);
                        p22 = sol2(idx2);

                        while (p22 == p2)
                            idx2 = randi(c2);
                            p22 = sol2(idx2);
                        end

                        %Crossover (SBX+uniform) + Mutate !
                        child(count) = crossover(child(count), population(p1), population(p11), cf);
                        tempchild1 = crossover(tempchild1, population(p11), population(p1), cf);

                        if rand(1) < 1
                            child(count) = mutate(child(count), child(count), D_multitask, mum);
                            tempchild1 = mutate(tempchild1, tempchild1, D_multitask, mum);
                        end

                        %variable swap
                        swap_indicator = (rand(1, D_multitask) >= probswap);
                        temp = tempchild1.rnvec(swap_indicator);
                        child(count).rnvec(swap_indicator) = temp;

                        child(count + 1) = crossover(child(count + 1), population(p2), population(p22), cf);
                        tempchild2 = crossover(tempchild2, population(p22), population(p2), cf);

                        if rand(1) < 1
                            child(count + 1) = mutate(child(count + 1), child(count + 1), D_multitask, mum);
                            tempchild2 = mutate(tempchild2, tempchild2, D_multitask, mum);
                        end

                        %variable swap
                        swap_indicator = (rand(1, D_multitask) >= probswap);
                        temp = tempchild2.rnvec(swap_indicator);
                        child(count + 1).rnvec(swap_indicator) = temp;

                        child(count).skill_factor = population(p1).skill_factor;
                        child(count + 1).skill_factor = population(p2).skill_factor;

                    end
                    count = count + 2;
                end

                for i = 1:pop
                    [child(i), calls_per_individual(i)] = evaluate(child(i), Tasks, p_il, no_of_tasks, options);
                end
                fnceval_calls = fnceval_calls + sum(calls_per_individual);
                TotalEvaluations(generation) = fnceval_calls;

                rmpval(generation) = rmp;

                intpopulation(1:pop) = population;
                intpopulation(pop + 1:2 * pop) = child;
                factorial_cost = zeros(1, 2 * pop);
                for i = 1:no_of_tasks
                    for j = 1:2 * pop
                        factorial_cost(j) = intpopulation(j).factorial_costs(i);
                    end
                    [xxx, y] = sort(factorial_cost);
                    intpopulation = intpopulation(y);
                    for j = 1:2 * pop
                        intpopulation(j).factorial_ranks(i) = j;
                    end
                    if intpopulation(1).factorial_costs(i) <= bestobj(i)
                        bestobj(i) = intpopulation(1).factorial_costs(i);
                        bestInd_data(i) = intpopulation(1);
                    end
                    EvBestFitness(i, generation) = bestobj(i);
                end
                for i = 1:2 * pop
                    [xxx, yyy] = min(intpopulation(i).factorial_ranks);
                    intpopulation(i).skill_factor = yyy;
                    intpopulation(i).scalar_fitness = 1 / xxx;
                end

                if strcmp(selection_process, 'elitist')
                    [xxx, y] = sort(- [intpopulation.scalar_fitness]);
                    intpopulation = intpopulation(y);
                    population = intpopulation(1:pop);
                elseif strcmp(selection_process, 'roulette wheel')
                    for i = 1:no_of_tasks
                        skill_group(i).individuals = intpopulation([intpopulation.skill_factor] == i);
                    end
                    count = 0;
                    while count < pop
                        count = count + 1;
                        skill = mod(count, no_of_tasks) + 1;
                        population(count) = skill_group(skill).individuals(RouletteWheelSelection([skill_group(skill).individuals.scalar_fitness]));
                    end
                end

                % Updates of the progresisonal representation models
                [mu_tasks, Sigma_tasks] = DistributionUpdate(mu_tasks, Sigma_tasks, population, no_of_tasks);

                % store all pairwise learned rmp values at every generation
                Upper = RMP(find(~triu(ones(size(RMP))))); % store upper triangle only since RMP matrix is symmetric.
                R(generation, :) = Upper';

                % disp(['AT-MFEA Generation = ', num2str(generation), ' best factorial costs = ', num2str(bestobj), '  rmp = ', num2str(RMP(1, 2)), ' (', num2str(index), '-th function: ', num2str(rep), '-time)']); %

            end %while

            % rmp_mean = mean(R, 3); % compute mean rmp values across desired number of independent runs.

            % data_MFEA.wall_clock_time = toc;
            % data_MFEA.EvBestFitness = EvBestFitness;
            % data_MFEA.bestInd_data = bestInd_data;
            % data_MFEA.TotalEvaluations = TotalEvaluations;
            % data_MFEA.rmp = rmpval; % data_MFEA.rmp=rmpval; includes identity values as well.
            % data_MFEA.R = R;
            % data_MFEA.rmpMean = rmp_mean; % mean rmp values across all independent runs

            data.clock_time = toc; % ????
            data.convergence = EvBestFitness;

        end

    end

end