$ ->
  IMP = window.IMP
  ###
  IMP.init('xxxxxxxxxx')
  IMP.request_pay
    pg : 'html5_inicis' # version 1.1.0부터 지원.
    pay_method : 'card' # 'card':신용카드, 'trans':실시간계좌이체, 'vbank':가상계좌, 'phone':휴대폰소액결제
    merchant_uid : 'merchant_' + new Date().getTime()
    name : '주문명:test#1'
    amount : 1000
    buyer_email : 'yongbin.yu@gmail.com'
    buyer_name : '유용빈'
    buyer_tel : '010-4241-0256'
    buyer_addr : '서울 광진구 화양동 48-3번지 웅진빌딩 403호'
    buyer_postcode : '143-193'
  , (res) ->
    if res.success
      console.log "고유ID: #{res.imp_uid}"
      console.log "상점거래ID: #{res.merchant_uid}"
      console.log "결제금액: #{res.paid_amount}"
      console.log "카드승인번호: #{res.apply_num}"
    else
      console.log res.error_msg
  ###
