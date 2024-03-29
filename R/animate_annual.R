#' Plot forest change (relative to 2000) for a given year
#'
#' Plots a single layer of forest change from a layer stack output by 
#' \code{\link{annual_stack}}.
#'
#' @seealso \code{\link{annual_stack}}, \code{\link{animate_annual}}
#' @export
#' @importFrom grid unit
#' @importFrom ggplot2 fortify geom_tile aes coord_fixed scale_fill_manual 
#' theme_bw theme element_blank geom_path guides guide_legend ggtitle
#' @importFrom plyr join
#' @importFrom rasterVis gplot
#' @importFrom sf st_transform st_crs
#' @param fchg a forest change raster layer (a single layer of the layer 
#' stack output by \code{\link{annual_stack}}
#' @param aoi one or more AOI polygons as a \code{SpatialPolygonsDataFrame} or \code{sf}
#' object.  If there is a 'label' field  in the dataframe, it will be used to 
#' label the polygons in the plots. If the AOI is not in WGS 1984 (EPSG:4326), 
#' it will be reprojected to WGS84.
#' @param title_string the plot title
#' @param size_scale a number used to scale the size of the plot text
#' @param maxpixels the maximum number of pixels from fchg to use in plotting
plot_gfc <- function(fchg, aoi, title_string='', 
                     size_scale=1, maxpixels=50000) {
    aoi <- check_aoi(aoi)
    aoi_tr <- st_transform(aoi, st_crs(fchg))

    rasterpts <- data.frame(rasterToPoints(fchg))
    names(rasterpts)[3] <- 'data'

    long=lat=value=label=ID=NULL # For R CMD CHECK
    gplot(fchg, maxpixels=maxpixels) +
        geom_tile(aes(fill=factor(value, levels=c(1, 2, 3, 4, 5, 6, 0)))) +
        coord_fixed() + 
        scale_fill_manual("Cover",
                         breaks=c("1", "2", "3", "4", "5", "6", "0"),
                         labels=c('Forest', # 1
                                  'Non-forest', # 2
                                  'Forest loss', # 3
                                  'Forest gain', # 4
                                  'Loss and gain', # 5
                                  'Water', # 6
                                  'No data'), # 0
                          values=c('#008000', # forest
                                   '#ffa500', # non-forest
                                   '#ff0000', # forest loss
                                   '#0000ff', # forest gain
                                   '#ff00ff', # loss and gain
                                   '#c0c0c0', # water
                                   '#101010'), # no data
                          drop=FALSE) +
        theme_bw(base_size=8*size_scale) +
        theme(axis.text.x=element_blank(), axis.text.y=element_blank(),
              axis.title.x=element_blank(), axis.title.y=element_blank(),
              panel.background=element_blank(), panel.border=element_blank(),
              panel.grid.major=element_blank(), panel.grid.minor=element_blank(),
              plot.background=element_blank(), axis.ticks=element_blank(),
              plot.margin=unit(c(.1, .1, .1, .1), 'cm')) +
        guides(linetype=guide_legend(title="Region", keywidth=2.5, 
                                     override.aes=list(alpha=1))) +
        ggtitle(title_string)

}

#' Plot an animation of forest change within a given area of interest (AOI)
#'
#' Produces an animation of annual forest change in the area bounded by the 
#' extent of a given AOI, or AOIs. The AOI polygon(s) is(are) also plotted on 
#' the image.  The \code{gfc_stack} must be pre-calculated using the 
#' \code{\link{annual_stack}} function. The animation can be either an animated 
#' GIF (if \code{type} is set to 'gif') or a series of '.png' files with a 
#' corresponding '.html' webpage showing a simple viewer and the forest change 
#' animation (if \code{type} is set to 'html'). The HTML option is recommended 
#' as it requires no additional software to produce it. The animated GIF option 
#' will only work if the imagemagicK software package is installed beforehand 
#' (this is done outside of R).
#'
#' @seealso \code{\link{annual_stack}}
#'
#' @export
#' @importFrom tools file_ext
#' @importFrom utils file_test
#' @import animation
#' @param aoi one or more AOI polygons as a \code{SpatialPolygonsDataFrame} or \code{sf}
#' object.  If there is a 'label' field  in the dataframe, it will be used to 
#' label the polygons in the plots. If the AOI is not in the WGS84 geographic 
#' coordinate system, it will be reprojected to WGS84.
#' @param gfc_stack a GFC product subset as a 
#' \code{RasterStack} (as output by \code{\link{annual_stack}})
#' @param out_dir folder for animation output
#' @param out_basename basename to use when naming animation files
#' @param site_name name of the site (used in making title)
#' @param type type of animation to make. Can be either "gif" or "html"
#' @param height desired height of the animation GIF in inches
#' @param width desired width of the animation GIF in inches
#' @param dpi dots per inch for the output image
#' @param dataset which version of the Hansen data to use
#' \code{\link{annual_stack}} was run
animate_annual <- function(aoi, gfc_stack, out_dir=getwd(), 
                           out_basename='gfc_animation', site_name='', 
                           type='html', height=3, width=3, dpi=300,
                           dataset='GFC-2022-v1.10') {
    aoi <- check_aoi(aoi)
    data_year <- as.numeric(str_extract(dataset, '(?<=GFC-?)[0-9]{4}'))

    if (!file_test('-d', out_dir)) {
        dir.create(out_dir)
    }
    out_dir <- normalizePath(out_dir)
    ani.options(outdir=out_dir, ani.width=width*dpi, ani.height=height*dpi, 
                verbose=FALSE)

    if (tolower(file_ext(out_basename)) != '') {
        stop('out_basename should not have an extension')
    }

    if (!(type %in% c('gif', 'html'))) {
        stop('type must be gif or html')
    }

    dates <- seq(1, data_year)

    # Round maxpixels to nearest 1000
    maxpixels <- ceiling((width * height * dpi^2)/1000) * 1000
    if (type == 'gif') {
        out_file <- paste(out_basename, '.gif')
        saveGIF({
                    for (n in 1:nlayers(gfc_stack)) {
                        p <- plot_gfc(gfc_stack[[n]], aoi, dates[n], 
                                      size_scale=4, maxpixels)
                        print(p)
                    }
                }, interval=0.5, movie.name=out_file)
    } else if (type == 'html') {
        saveHTML({
                    for (n in 1:nlayers(gfc_stack)) {
                        p <- plot_gfc(gfc_stack[[n]], aoi, dates[n], 
                                      size_scale=4, maxpixels)
                        print(p)
                    }
                 },
                 img.name=out_basename,
                 imgdir=paste0(out_basename, '_imgs'),
                 outdir=out_dir,
                 htmlfile=paste0(out_basename, ".html"),
                 autobrowse=FALSE,
                 title=paste(site_name, 'forest change'))
    }
}
