$ ->
  $('.btn-size').click (e) ->
    $('.btn-size').removeClass('active')
    $(@).addClass('active')

    index = parseInt($(@).data('index'))
    size  = $(@).data('size')

    $table = $(@).closest('table')
    $table.find('td').removeClass('success')
    $(@).closest('table').find("tbody tr td:nth-child(#{index + 2})").toggleClass('success')

    which = $(@).data('which')
    $("input[name=#{which}_size]").val(size)

  $('.btn-size.active').trigger('click')

  $('input[name=height],input[name=weight],input[name=waist],input[name=bust],input[name=topbelly],input[name=hip],input[name=thigh]').focusout (e) ->
    gender = $('#gender').data('gender')
    query = "#{$('#form-body-dimensions').serialize()}&gender=#{gender}"

    waist    = $('input[name=waist]').val()
    bust     = $('input[name=bust]').val()
    topbelly = $('input[name=topbelly]').val()
    $.ajax '/body/dimensions',
      type: 'GET'
      dataType: 'json'
      data: query
      success: (data, textStatus, jqXHR) ->
        top = data.ready_to_wear_size.top.replace(/[^0-9]/g, '')
        bottom = data.ready_to_wear_size.bot.replace(/[^0-9]/g, '')

        $('.suggestion-body.suggestion-top strong').text(top)
        $('.suggestion-body.suggestion-bottom strong').text(bottom)
      error: (jqXHR, textStatus, errorThrown) ->
        err = jqXHR.responseJSON.error
        $('.suggestion-body.suggestion-top strong').text('')
        $('.suggestion-body.suggestion-bottom strong').text('')
      complete: (jqXHR, textStatus) ->
