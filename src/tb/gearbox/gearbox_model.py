

class RxGearboxModel:
    def __init__(self, type='int'):
        if type == 'str':
            self.obuf = ['XXX' for _ in range(67)] # Extra bit for half slip
        else:
            self.obuf = [0 for _ in range(67)]
        self.cycle = 0
        self.half_slip = 0


    def next(self, idata, slip=False):

        self.slip = slip
        self.count = int(self.cycle % 33)
        self.valid = self.count != 0
        self.frame_word = int(self.count % 2 == 0)
        self.output_header = int(self.count % 2 == 1)

        data_idxs = [00,32,64,30,62,28,60,26,58,24,56,22,54,20,52,18,50,16,48,14,46,12,44,10,42,8,40,6,38,4,36,2,34]

        # if self.count % 2 == 0:
        #     idata_idx = (66 - self.count) % 66
        #     obuf[idata_idx:66] = idata[0 : self.count]
        #     obuf[0:32-self.count] = idata[self.count:]

        # else:
        #     idata_idx = ((66 - self.count - 32) - 1) % 66
        #     obuf[idata_idx : self.idata_idx + 32] = idata

        # bit select method

        for bit in range(len(self.obuf)):

            self.idata_idx = data_idxs[self.count]

            if self.count % 2 == 0:
                if self.idata_idx != 0 and bit >= self.idata_idx and bit < 66:
                    self.obuf[bit] = idata[bit-self.idata_idx]
                elif bit < 32 - self.count:
                    self.obuf[bit] = idata[self.count + bit]
            else:
                if bit >= self.idata_idx and bit < self.idata_idx + 32:
                    self.obuf[bit] = idata[bit - self.idata_idx]
    
        self.obuf[66] = self.obuf[0]

        if self.half_slip % 2 == 0:
            self.odata = self.obuf[2 : 34] if self.frame_word == 0 else self.obuf[34:66]
            self.oheader = self.obuf[0:2]
        else:
            self.odata = self.obuf[3 : 35] if self.frame_word == 0 else self.obuf[35:67]
            self.oheader = self.obuf[1:3]

        ret = {
            'data' : self.odata,
            'header' : self.oheader,
            'data_valid' : self.valid,
            'header_valid' : self.output_header,
            'obuf' : self.obuf,
            'cycle' : self.cycle
        }

        if not self.slip:
            self.cycle = self.cycle + 1

        if slip:
            self.half_slip = self.half_slip + 1

        return ret

        


    def get_state(self):

        return f'{self.count:03d}\t{self.slip:b}\t{self.valid}\t{int(self.output_header)}\t{self.idata_idx:02d}\t{self.oheader}\t{self.odata}'


class TxGearboxModel:
    def __init__(self, type='int'):
        if type == 'str':
            self.obuf = ['XXX' for _ in range(66)]
        else:
            self.obuf = [0 for _ in range(66)]
        self.cycle = 0
        self.half_slip = 0
        self.count = int(self.cycle % 33)
        self.pause = self.count == 32
        


    def next(self, iheader, idata):

        self.count = int(self.cycle % 33)
        self.pause = self.count == 32
        self.frame_word = int(self.count % 2 == 1)
        self.load_header = int(self.count % 2 == 0)
        self.header_idx = self.count if self.load_header else -1
        self.data_idx = self.count + 2 if self.load_header else self.count + 1


        
        # obuf[0:32] = obuf[32:64]
        # if not self.pause:
        #     if self.load_header:
        #         obuf[self.header_idx:self.header_idx+2] = header
        #     obuf[self.data_idx:self.data_idx+32] = data[self.frame_word*32 : 32 + self.frame_word*32]

        # odata.append(obuf[0:32])

        # bit select method
        for bit in range(len(self.obuf)):
            if bit < 32:
                self.obuf[bit] = self.obuf[bit+32]

            if not self.pause:
                if self.load_header:
                    if bit >= self.header_idx and bit < self.header_idx + 2:
                        self.obuf[bit] = iheader[bit-self.header_idx]
                    
                if bit >= self.data_idx and bit < self.data_idx + 32:
                        self.obuf[bit] = idata[bit - self.data_idx]

        self.odata = self.obuf[:32]

        self.cycle = self.cycle + 1

        return {
            'data' : self.odata,
            'pause' : self.pause,
            'obuf' : self.obuf,
            'cycle' : self.cycle
        }
       
    def get_frame_word(self):
        self.count = int(self.cycle % 33)
        self.frame_word = int(self.count % 2 == 1)
        return self.frame_word

    def get_pause(self):
        self.count = int(self.cycle % 33)
        self.pause = self.count == 32
        return self.pause

    def get_count(self):
        self.count = int(self.cycle % 33)
        return self.count

    def get_state(self):

        return f'{self.count:03d}\t{self.pause}\t{int(self.load_header)}\t{self.header_idx:02d}\t{self.data_idx:02d}\t{int(self.frame_word)}\t{self.odata}'
    
    def get_state_header(self):
        return f'count\tpause\theader?\theader_idx\tdata_idx\tframe_word\todata'