# Given a `df`, `trait_var`, and `effect_var`, plot combined box plot/Sina plot showing density distribution of points by region

solutions_boxswarm <- function(df, effect_var, y_title){
  
  effect_var <- rlang::enquo(effect_var)
  
  df %>%
    arrange(region) %>% 
    dplyr::mutate(region2 = forcats::as_factor(region),
                  region = forcats::as_factor(region)) %>%
    dplyr::rename(value := !!effect_var) %>% 
    ggplot2::ggplot(aes(x = forcats::fct_reorder(region,
                                                 value,
                                                 median),
                        y = value)) +
    ggforce::geom_sina(aes(color = region2),
                       alpha = 0.25,
                       kernel = "rectangular") +
    ggplot2::scale_color_manual(values = c("1" = "tomato2",
                                           "2" = "darkslategray4",
                                           "3" = "springgreen3",
                                           "5" = "goldenrod1",
                                           "7" = "deeppink3",
                                           "8" = "gray17",
                                           "9" = "slateblue2"),
                                labels = c("1" = "Desert",
                                           "2" = "Southeast",
                                           "3" = "High Plains",
                                           "5" = "Arid Prairie",
                                           "7" = "Forested Mountains",
                                           "8" = "Fescue Belt",
                                           "9" = "Upper Midwest & Northeast")) +
    ggplot2::geom_boxplot(aes(fill = region2),
                          alpha = 0.1,
                          show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = c("1" = "tomato2",
                                          "2" = "darkslategray4",
                                          "3" = "springgreen3",
                                          "5" = "goldenrod1",
                                          "7" = "deeppink3",
                                          "8" = "gray17",
                                          "9" = "slateblue2")) +  
    ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(alpha = 1),
                                                   nrow = 3,
                                                   byrow = TRUE)) +
    ggplot2::theme_classic() +
    ggplot2::theme(axis.title = ggplot2::element_text(size = 16),
                   axis.title.x = element_blank(),
                   axis.title.y = ggplot2::element_text(margin = margin(t = 0,
                                                                        r = 13,
                                                                        b = 0,
                                                                        l = 0)),
                   axis.text = ggplot2::element_text(size = 14),
                   axis.text.x = element_blank(),
                   axis.ticks.x = element_blank(),
                   legend.text = ggplot2::element_text(size = 14),
                   legend.position = "bottom",
                   legend.margin = margin(),
                   legend.box.just = "left",
                   legend.justification = "left") +
    ggplot2::labs(x = NULL,
                  y = y_title,
                  title = NULL,
                  color = NULL)
  
}