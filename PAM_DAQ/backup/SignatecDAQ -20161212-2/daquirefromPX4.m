function daquirefromPX4(handles)

handles.tcpipClient = getappdata(0, 'tcpipClient');

while getappdata(0, 'isRunning') == 1 
    while (handles.tcpipClient.BytesAvailable > 0)
        
        disp('reading')
        try
            params = fread(handles.tcpipClient,getappdata(0,'DataBuffSz')/8,'uint16');
            disp('DAQ parameters read');
            % params = [number of pixel to acquire per line, number of rows; number of extra triggers for flyback; patternType; line averaging;...
            %            range along the width direction in microns; range along the height direction in microns]
        catch Ex
            disp('could not fetch data acquisition parameters from host');
            return
        end
        
        %% pattern type: 0 for bscans and iterate over rows; 1 for volume scan for a single file per image
        patternType = params(4);
        
        % update GUI
        updateGUI(handles, params);
        
        tStamp = clock;
        name_suffix = [num2str(tStamp(1)), num2str(tStamp(2), '%02d'), num2str(tStamp(3), '%02d'), '-', num2str(tStamp(4),'%02d'),num2str(tStamp(5),'%02d')];
        ImgName = [getappdata(0, 'ImgNameRoot'), '-', name_suffix];
        
        if params(2) == 1  % if a B scan with a single line do not save, just dump to temp
            mkdir(getappdata(0, 'datadir'), 'LinePlotTemp');
        else
            mkdir(getappdata(0, 'datadir'), ImgName);
        end
        
        if patternType == 0
        
            % set Signatec parameters
            setAcqMem(handles, params);

            for i=1:params(2) %loop over line number
                
                %% Notify server that acquisition is ready for triggers
                % send the server a flag that params has been received.FLAG: 7 params
                % received and trigger armed
                disp('sending ready signal...')
                fwrite(handles.tcpipClient, 7, 'uint16');
                
                
               % arm Signatec trigger
                armSignaTrig(handles.phBrd);
                disp('trigger armed')
                %% setup acquisition sychronously
                disp(['Acquiring line ', num2str(i)]);
                AcqSigna1Line(handles.phBrd, params);
                
                if params(2) == 1
                    SaveLine2Temp(handles, params);
                    makeLinePltFromData(params);
                    
                else
                    SaveLine2File(handles, params, ImgName, i);
                    %% writing metadata file file (context of acquisition)
                    writeMetaData;
                end
            end
            
        elseif patternType == 1
            % set Signatec parameters
            setAcqMemStack(handles, params);

            %% Notify server that acquisition is ready for triggers
            % send the server a flag that params has been received.FLAG: 7 params
            % received and trigger armed
            disp('sending ready signal...')
            fwrite(handles.tcpipClient, 7, 'uint16');

            %% arm Signatec trigger
            armSignaTrig(handles.phBrd);

            %% setup acquisition sychronously
            disp('Acquiring Stack ...');
            AcqSignaStack(handles.phBrd, params);
            SaveStack2File(handles, params, ImgName);
            %% writing metadata file file (context of acquisition)
            flushSignaRAM(handles.phBrd, params);
            
            writeMetaData;
        end  
        
        
        
        
    end
    
    pause(1);
    
end

end

function updateGUI(handles, params)
    
    %% update connection status
    set(handles.hCnctStatsFld, 'String', 'Connected to host')
    
    %% update image parameters
    set(handles.hHrzPixFld, 'String', num2str(params(1)));
    set(handles.hVertLineFld, 'String', num2str(params(2)));
    set(handles.hFlybkFld, 'String', num2str(params(3)));
    set(handles.hLineAvrgFld, 'String', num2str(params(4)));
    
    %% update acquisition status
    set(handles.hAcqStatsFld, 'String', 'Waiting for trigger');
end         