with tab1 as (
    select
        s.visitor_id,
        s.visit_date,
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number()
            over (partition by s.visitor_id order by s.visit_date desc)
        as rn
    from sessions as s
    left join leads as l on s.visitor_id = l.visitor_id
    order by
        l.amount desc nulls last,
        s.visit_date asc,
        utm_source asc,
        utm_medium asc,
        utm_campaign asc
)

select
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    created_at,
    amount,
    closing_reason,
    status_id
from tab1
where
    rn = 1
    and (
        utm_source = 'youtube'
        or utm_source = 'telegram'
        or utm_medium = 'cpc'
        or utm_medium = 'cpm'
        or utm_medium = 'cpa'
        or utm_medium = 'cpp'
        or utm_medium = 'social'
    )