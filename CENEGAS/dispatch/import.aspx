<%@ Page Language="C#" AutoEventWireup="true" %><% 
                                                    
                                                    
                                                    
    System.Globalization.CultureInfo beforeCulture = System.Threading.Thread.CurrentThread.CurrentCulture;

    try
    {
        HttpPostedFile csvHours = (HttpPostedFile)Request.Files["horarios"];
        HttpPostedFile csvSummary = (HttpPostedFile)Request.Files["promedios"];

        System.Threading.Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo("es-MX");



        string idsesion = Request.Params["idsesion"];

        bool useRange = bool.Parse(Request.Params["useRange"]);
        bool viewHowChanges = bool.Parse(Request.Params["viewHowChanges"]);

        DateTime initDate = DateTime.Now;
        DateTime finalDate = initDate;

        if (useRange)
        {
            initDate = DateTime.Parse(Request.Params["initDate"]);
            finalDate = DateTime.Parse(Request.Params["finalDate"]);
        }


        if (csvHours != null && csvSummary != null)
            cenegas.clases.importar.import(idsesion, csvHours, csvSummary, useRange, viewHowChanges, initDate, finalDate, Response);

    }
    catch (Exception e)
    {
        Response.Output.Write( e.Message );

    }
    finally {

        System.Threading.Thread.CurrentThread.CurrentCulture = beforeCulture;
    }
                                                                                     
%>
