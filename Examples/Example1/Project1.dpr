// https://github.com/leixiaohua1020/simplest_encoder

program Project1;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  WinApi.Windows,
  System.Classes,
  x265 in '..\..\Include\x265.pas';


(* Prepare a dummy image. *)
Procedure fill_yuv_image(var pict : Px265_picture; frame_index: integer;
                           width: integer; height: integer);
var
  x, y, i : integer;
begin
  i := frame_index;
  (* Y *)
  for y := 0 to height-1 do
    for x := 0 to width-1 do
      pByte(pict^.planes[0])[y * pict^.stride[0] + x] := x + y + i * 3;

  (* Cb and Cr *)
  for y := 0 to (height div 2)-1 do
    for x := 0 to (width div 2)-1 do
    begin
      pByte(pict^.planes[1])[y * pict^.stride[1] + x] := 128 + y + i * 2;
      pByte(pict^.planes[2])[y * pict^.stride[2] + x] := 64 + x + i * 5;
    end;
end;


var
  LSourceFile       : TFileStream;

  LParam            : Px265_param;
  LEncoder          : Px265_encoder;
  LPicSrc           : Px265_picture;
  LStatsSizeBytes   : cardinal;
  LStats            : Px265_stats;
  LRet              : integer;
  LBuff             : PByte;
  LpNals            : Px265_nal;
  LiNal             : cardinal;
  i                 : integer;
  LSourceFileName   : string;
  Lx265FileName     : string;
  LSourceWidth      : string;
  LSourceHeight     : string;
  LLumaSize         : integer;
  LChromaSize       : integer;
begin
  ReportMemoryLeaksOnShutdown := true;

  try

    if ((not FindCmdLineSwitch('i', LSourceFileName, True)) or (not FindCmdLineSwitch('w', LSourceWidth, True)) or (not FindCmdLineSwitch('h', LSourceHeight, True)))  then
    begin
      Writeln(ErrOutput, Format('usage: %s -w [Width] -h [Height] -i [input file] -o [output file]', [ExtractFileName(ParamStr(0))]));
      Exit;
    end;
    FindCmdLineSwitch('o', Lx265FileName, True);

    LSourceFile := TFileStream.Create(LSourceFileName, fmOpenRead);
    try
      LParam := nil;
      LParam := x265_param_alloc();
      try
        x265_param_default(LParam);
        LRet := x265_param_apply_profile(LParam, 'main');
        if LRet < 0 then
        begin
          WriteLn('x265_param_apply_profile error.');
          exit;
        end;

        LRet := x265_param_default_preset(LParam, 'ultrafast', 'zerolatency');
        if LRet < 0 then
        begin
          WriteLn('x265_param_default_preset error.');
          exit;
        end;
        LParam.frameNumThreads := X265_MAX_FRAME_THREADS; //TThread.ProcessorCount;
        LParam.bRepeatHeaders:= 1; //write sps,pps before keyframe
        LParam.internalCsp:= X265_CSP_I420;
        //x265_param_parse(LParam, 'input-res', '640x360'); //wxh
        LParam.sourceWidth:= StrToInt(LSourceWidth);
        LParam.sourceHeight:= StrToInt(LSourceHeight);
        LParam.fpsNum:= 25;
        LParam.fpsDenom:= 1;
        x265_param_parse(LParam, 'fps', '25');

        // init picture
        LPicSrc := nil;
        LPicSrc	:= x265_picture_alloc();
        try
          x265_picture_init(LParam, LPicSrc);

          // init encoder
          LEncoder := nil;
          LEncoder := x265_encoder_open(LParam);
          if not assigned(LEncoder) then
          begin
            writeln('x265_encoder_open error.');
            exit;
          end;
          try
            LLumaSize := StrToInt(LSourceWidth) * StrToInt(LSourceHeight);
            LChromaSize := StrToInt(LSourceWidth) div 4;

            LBuff := AllocMem(LLumaSize * 3 div 2);

            LPicSrc.planes[0]:= LBuff;
            LPicSrc.planes[1]:= LBuff + LLumaSize;
            LPicSrc.planes[2]:= LBuff + LLumaSize * 5 div 4;

            LPicSrc.stride[0]:= LParam.sourceWidth;
            LPicSrc.stride[1]:= LParam.sourceWidth div 2;
            LPicSrc.stride[2]:= LParam.sourceWidth div 2;





            for i := 1 to 5 do
            begin
              //fill_yuv_image(LPicSrc,  StrToInt(LSourceWidth), StrToInt(LSourceHeight), i);
              LSourceFile.ReadData(LPicSrc.planes[0], LLumaSize);      // Y
              LSourceFile.ReadData(LPicSrc.planes[1], LChromaSize);    // U
              LSourceFile.ReadData(LPicSrc.planes[2], LChromaSize);    // V

              LRet:= x265_encoder_encode(LEncoder, LpNals, LiNal, LPicSrc, nil);
              writeln(Format('Succeed encode %5d frames',[i]));

              LStats := nil;
              x265_encoder_get_stats(LEncoder, LStats, LStatsSizeBytes);

              //for(j=0;j<iNal;j++) do
              //begin
              //  fwrite(pNals[j].payload,1,pNals[j].sizeBytes,fp_dst);
              //end;
            end;

            //Flush Decoder
            while true  do
            begin
              if x265_encoder_encode(LEncoder, LpNals, LiNal,nil,nil) = 0 then
                break;
              writeln('Flush 1 frame.');
            end;
          finally
            x265_encoder_close(LEncoder);
            x265_cleanup();
          end;
        finally
          x265_picture_free(LPicSrc);
        end;
      finally
        x265_param_free(LParam);
      end;
    finally
      FreeAndNil(LSourceFile);
    end;
    readln
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
